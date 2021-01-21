defmodule Connection do
  use Task
  require Logger
  defstruct type: nil, socket: nil, user: nil, name: nil, state: nil, accumulator: <<>>, counter: 0, last_update: 0, skew_warned: false, ip: nil, ssl: false

  @callback init(String.t, Map.t) :: {:ok, Map.t} | :error
  @callback handle_payload(Map.t, String.t, Integer.t) :: {:ok, String.t, Map.t} | {:more, Map.t}
  @callback write(Map.t, Map.t) :: Map.t
  @callback close(Map.t) :: Map.t

  def start_link([socket: socket, ssl: ssl]) do
    opts = [active: true, nodelay: true]
    if ssl do
      :ssl.setopts(socket, opts)
      Task.start_link(__MODULE__, :handshake_ssl, [%Connection{socket: socket, ssl: true}])
    else
      :inet.setopts(socket, opts)
      Task.start_link(__MODULE__, :run, [%Connection{socket: socket, ssl: false}])
    end
  end

  def handshake_ssl(state) do
    case :ssl.handshake(state.socket) do
      {:ok, socket, _} ->
        run(%{state | socket: socket})
      {:ok, socket} ->
        run(%{state | socket: socket})
      {:error, reason} ->
        Logger.info("SSL handshake failed for #{inspect(self())}: #{inspect(reason)}")
    end
  end
  
  def run(state) do
    next_state =
      receive do
      {:ssl, socket, data} ->
        handle_data(socket, data, state)
      {:tcp, socket, data} ->
        handle_data(socket, data, state)
      {:ssl_closed, _} ->
        Logger.info("SSL closed #{inspect(self())} #{inspect(state.user)}")
        %{state | state: :closed}
      {:tcp_closed, _} ->
        Logger.info("TCP closed #{inspect(self())} #{inspect(state.user)}")
        %{state | state: :closed}
      {:ssl_error, _, _} ->
        Logger.info("SSL error #{inspect(self())} #{inspect(state.user)}")
        %{state | state: :closed}
      {:tcp_error, _} ->
        Logger.info("TCP error #{inspect(self())} #{inspect(state.user)}")
        %{state | state: :closed}
      {:send, msg} ->
        write(state, msg)
      :close ->
        close(state)
    after 30000 ->
        case state.state do
          nil ->
            ## Timeout on connect, just close.
            shutdown(state)
          {:timeout, 5, _} ->
            Logger.info("Connection #{inspect(self())} timed out, closing")
            close(state)
          {:timeout, n, p} ->
            write(state, Update.make(Update.Ping, []))
            %{state | state: {:timeout, n+1, p}}
          _ ->
            write(state, Update.make(Update.Ping, []))
            %{state | state: {:timeout, 1, state.state}}
        end
    end
    if next_state.state != :closed, do: run(next_state)
  end

  def handle_data(socket, data, state) do
    state = if state.type == nil do
      init(data, %{state | socket: socket})
    else
      %{state | socket: socket}
    end
    ## Clear timeout
    state = case state.state do
              {:timeout, _, p} -> %{state | state: p}
              _ -> state
            end
    
    case handle_payload(state, data) do
      {:ok, update, state} ->
        handle_update(state, update)
      {:more, state} ->
        state
      {:error, reason, state} ->
        Logger.info("Handler failure: #{reason}")
        shutdown(state)
      :shutdown ->
        shutdown(state)
    end
  end

  def throttle(state) do
    {max, period} = Toolkit.config(:max_updates_per_connection)
    time = Toolkit.time()
    cond do
      period <= (time - state.last_update) ->
        {:ok, %{state | last_update: time, counter: 0}}
      state.counter < max ->
        {:ok, %{state | counter: state.counter + 1}}
      true ->
        {:error, state}
    end
  end

  def handle_update(state, data) do
    try do
      case throttle(state) do
        {:ok, state} ->
          case state.state do
            nil ->
              if update.type.__struct__ == Update.Connect do
                Update.handle(update, state)
              else
                write(state, Update.fail(Update.InvalidUpdate))
                close(state)
              end
            :closed ->
              close(state)
            _ ->
              {state, update} = handle_clock(state, Update.parse(data))
              update = case update.from do
                         nil -> %{update | from: state.name}
                         _ -> update
                       end
              if update.from != state.name do
                write(state, Update.fail(update, Update.UsernameMismatch))
              else
                case Update.permitted?(update) do
                  false -> write(state, Update.fail(update, Update.InsufficientPermissions))
                  :error -> write(state, Update.fail(update, Update.MalformedUpdate))
                  :no_such_channel -> write(state, Update.fail(update, Update.NoSuchChannel))
                  :no_such_parent -> write(state, Update.fail(update, Update.NoSuchParentChannel))
                  :timeout -> write(state, Update.fail(update, Update.TooManyUpdates))
                  true -> Update.handle(update, state)
                end
              end
          end
        {:error, state} ->
          write(state, Update.fail(update, Update.TooManyUpdates))
      end
    rescue
      e in Error.ParseFailure ->
        write(state, Update.fail(Update.MalformedUpdate, e.message))
        if state.state == nil, do: close(state), else: state
      e in Error.UnsupportedUpdate ->
        write(state, Update.fail(Update.InvalidUpdate, e.message))
      e in RuntimeError ->
        write(state, Update.fail(Update.Failure, e.message))
        if state.state == nil, do: close(state), else: state
    end
  end

  def handle_clock(state, update) do
    time = Toolkit.universal_time()
    cond do
      time+10 < update.clock ->
        if not state.skew_warned do
          write(state, Update.fail(update, Update.ClockSkewed,
                "Your clock is fast by #{update.clock-time}. You should synchronise it with a time server."))
        end
        {%{state | skew_warned: true}, %{update | clock: time}}
      update.clock < time-60 ->
        if not state.skew_warned do
          write(state, Update.fail(update, Update.ClockSkewed,
                "Your clock is slow by over one minute. You should synchronise it with a time server."))
        end
        {%{state | skew_warned: true}, %{update | clock: time}}
      update.clock < time-20 ->
        write(state, Update.fail(update, Update.ConnectionUnstable))
        {state, update}
      true ->
        {state, update}
    end
  end

  def init(data, state) do
    {:ok, {addr, _port}} = :inet.peername(state.socket)
    state = %{state | ip: addr}
    Enum.find_value([Websocket, RawTCP], state, fn module ->
      case module.init(data, state) do
        {:ok, state} ->
          if Blacklist.has?(state.ip) do
            Logger.info("Connection from #{:inet_parse.ntoa(addr)} denied: on blacklist")
            %{state | type: nil}
          else
            Logger.info("New #{inspect(module)} connection from #{:inet_parse.ntoa(state.ip)} at #{inspect(self())}")
            state
          end
        :error -> nil
      end
    end)
  end

  def handle_payload(state, data) do
    case state.type do
      nil -> :shutdown
      _ -> state.type.handle_payload(state, data, Toolkit.config(:max_update_size, 8388608))
    end
  end

  def write(state, data) when is_binary(data) do
    if state.ssl do
      :ssl.send(state.socket, data)
    else
      :gen_tcp.send(state.socket, data)
    end
    state
  end

  def write(state, data) do
    state.type.write(state, data)
  end

  def close(state) do
    state.type.close(state)
  end
  
  def establish(state, update) do
    primary = Lichat.server_name()
    user = User.connect(User.ensure_user(update.from), self())
    write(state, Update.reply(update, Update.Connect, [
              from: update.from,
              version: Lichat.version(),
              extensions: Lichat.extensions()]))
    write(state, Update.make(Update.Join, [
              from: update.from,
              channel: primary
              ]))
    Enum.each(User.channels(user), fn {_channel, {_ref, name}} ->
      if name != primary do
        write(state, Update.make(Update.Join, [
                  from: update.from,
                  channel: name ]))
      end
    end)
    %{state | state: :connected, user: user, name: update.from}
  end

  def shutdown(state) do
    if state.ssl do
      :ssl.shutdown(state.socket, :write)
    else
      :gen_tcp.shutdown(state.socket, :write)
    end
    %{state | state: :closed}
  end
end
