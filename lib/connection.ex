defmodule Lichat.Connection do
  use Task
  require Logger
  defstruct type: nil,
    socket: nil,
    user: nil,
    name: nil,
    state: nil,
    accumulator: <<>>,
    counter: 0,
    last_update: 0,
    skew_warned: false,
    buffer: :queue.new,
    ip: nil,
    ssl: false,
    started_on: Toolkit.universal_time(),
    extensions: MapSet.new(),
    identities: %{},
    sql_id: nil

  @callback init(String.t, Map.t) :: {:ok, Map.t} | :error
  @callback handle_payload(Map.t, String.t, Integer.t) :: {:ok, String.t, Map.t} | {:more, Map.t}
  @callback write(Map.t, Map.t) :: Map.t
  @callback close(Map.t) :: Map.t

  def start_link([socket: socket, ssl: ssl]) do
    opts = [active: true, nodelay: true]
    if ssl do
      {:ok, {addr, _port}} = :ssl.sockname(socket)
      :ssl.setopts(socket, opts)
      start_link(:handshake_ssl, %Lichat.Connection{socket: socket, ip: addr, ssl: true})
    else
      {:ok, {addr, _port}} = :inet.peername(socket)
      :inet.setopts(socket, opts)
      start_link(:run, %Lichat.Connection{socket: socket, ip: addr, ssl: false})
    end
  end

  def start_link(target, state) do
    log(state, "Starting connection")
    Task.start_link(__MODULE__, target, [state])
  end

  def handshake_ssl(state) do
    case :ssl.handshake(state.socket, Toolkit.config(:ssl_timeout)) do
      {:ok, socket, _} ->
        case :ssl.handshake_continue(socket, [], Toolkit.config(:ssl_timeout)) do
          {:ok, socket} -> run(%{state | socket: socket})
          {:error, reason} ->
            log(state, "SSL handshake failed: #{inspect(reason)}")
            :ssl.close(state.socket)
        end
      {:ok, socket} ->
        run(%{state | socket: socket})
      {:error, reason} ->
        log(state, "SSL handshake failed: #{inspect(reason)}")
        :ssl.close(state.socket)
    end
  end
  
  def run(state) do
    next_state =
      receive do
      {:ssl, socket, data} ->
        handle_data(socket, data, state)
      {:tcp, socket, data} ->
        handle_data(socket, data, state)
      {:ssl_closed, reason} ->
        log(state, "SSL closed: #{inspect(reason)}")
        %{state | state: :closed}
      {:tcp_closed, reason} ->
        log(state, "TCP closed: #{inspect(reason)}")
        %{state | state: :closed}
      {:ssl_error, reason, _} ->
        log(state, "SSL error: #{inspect(reason)}")
        %{state | state: :closed}
      {:tcp_error, reason} ->
        log(state, "TCP error: #{inspect(reason)}")
        %{state | state: :closed}
      {:send, msg} ->
        write(state, msg)
      {:send, msg, from} ->
        write(state, msg)
        send from, {:sent, self(), msg}
        state
      :close ->
        close(state)
      :check_blacklist ->
        if Blacklist.has?(state.ip) do
          log(state, "Killing connection: on blacklist")
          close(state)
        else
          state
        end
      {:get_data, from} ->
        send from, {:data, state}
        state
      {:DOWN, _ref, :process, pid, _reason} ->
        case Map.pop(state.identities, pid) do
          {nil, _} -> state
          {{name, ref}, map} ->
            Process.demonitor(ref)
            %{state | identities: Map.drop(map, name)}
        end
      x ->
        Logger.warning("#{describe(state)} Weird message: #{inspect(x)}")
    after 1_000 ->
        case state.state do
          nil ->
            log(state, "Timed out before connecting, closing")
            shutdown(state)
          {:timeout, 120, _} ->
            log(state, "Timed out, closing")
            close(state)
          {:timeout, n, p} ->
            if rem(n, 30) == 0 do
              write(state, Update.make(Update.Ping, []))
            end
            %{state | state: {:timeout, n+1, p}}
          _ ->
            case :queue.out(state.buffer) do
              {{:value, update}, buffer} ->
                handle_update_direct(%{state | buffer: buffer}, update)
              {:empty, _} ->
                %{state | state: {:timeout, 1, state.state}}
            end
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
      {:ok, data, state} ->
        handle_update_raw(state, data)
      {:more, state} ->
        state
      {:error, reason, state} ->
        log(state, "Handler failure: #{reason}")
        shutdown(state)
      :shutdown ->
        shutdown(state)
    end
  end

  def handle_update_raw(state, data) do
    try do
      handle_update(state, Update.parse(data))
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

  def handle_update(state, update) do
    {max, period, maxbuffer} = Toolkit.config(:max_updates_per_connection)
    buflength = :queue.len(state.buffer)
    time = Toolkit.time()
    Sql.update_connection(state)
    cond do
      maxbuffer <= buflength ->
        log(state, "has been killed due to exceeded buffer queue.")
        write(state, Update.fail(update, Update.TooManyUpdates))
        close(state)
      0 < buflength ->
        %{state | buffer: :queue.in(update, state.buffer)}
      period <= (time - state.last_update) ->
        state = %{state | last_update: time, counter: 0}
        handle_update_direct(state, update)
      state.counter < max ->
        state = %{state | counter: state.counter + 1}
        handle_update_direct(state, update)
      true ->
        log(state, "has been put on buffer due to excessive messages.")
        write(state, Update.fail(Update.TooManyUpdates,
              "You have been sending too many messages and have been put on a queue."))
        %{state | buffer: :queue.in(update, state.buffer)}
    end
  end

  def handle_update_direct(state, update) do
    try do
      case state.state do
        nil ->
          if update.type.__struct__ == Update.Connect do
            Update.handle(update, state)
          else
              write(state, Update.fail(Update.InvalidUpdate,
                    "The first object must be a CONNECT update."))
            close(state)
          end
        :closed ->
          close(state)
        _ ->
          {state, update} = handle_clock(state, update)
          update = case update.from do
                     nil -> %{update | from: state.name}
                     _ -> update
                   end
          if update.from != state.name do
            write(state, Update.fail(update, Update.UsernameMismatch,
                  "The FROM field did not match your username: #{update.from} /= #{state.name}"))
          else
            case Update.permitted?(update) do
              false ->
                message = case Map.get(update.type, :channel) do
                            nil -> "#{update.from} does not have the permission to #{inspect(update.type.__struct__)}"
                            channel -> "#{update.from} does not have the permission to #{inspect(update.type.__struct__)} in #{channel}"
                          end
                Logger.info(message, [intent: :user])
                write(state, Update.fail(update, Update.InsufficientPermissions, message))
              :error ->
                write(state, Update.fail(update, Update.MalformedUpdate))
              :no_such_channel ->
                Failure.no_such_channel(state, update)
              :no_such_parent ->
                write(state, Update.fail(update, Update.NoSuchParentChannel,
                      "The parent channel for #{update.type.channel} does not exist."))
              :timeout ->
                write(state, Update.fail(update, Update.TooManyUpdates))
              true ->
                Update.handle(update, state)
            end
          end
      end
    rescue
      Protocol.UndefinedError ->
        write(state, Update.fail(Update.MalformedUpdate))
      if state.state == nil, do: close(state), else: state
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
    Enum.find_value([Websocket, IRC, RawTCP], state, fn module ->
      case module.init(data, state) do
        {:ok, state} ->
          if Blacklist.has?(state.ip) do
            log(state, "Connection from denied: on blacklist")
            IpLog.record(state, Update.TooManyConnections)
            %{state | type: nil}
          else
            log(state, "New #{inspect(module)} connection")
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
    state = %{state | extensions: (if update.type.extensions == nil, do: [], else: MapSet.new(update.type.extensions))}
    primary = Lichat.server_name()
    user = User.connect(User.ensure_user(update.from), self())
    IpLog.record(state, Update.Connect)
    state = %{state | sql_id: Sql.create_connection(state)}
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
    write(state, Update.make(Update.Message, [
              from: primary,
              channel: primary,
              text: Toolkit.banner()
              ]))
    %{state | state: :connected, user: user, name: update.from}
  end

  def shutdown(state) do
    Sql.delete_connection(state)
    IpLog.record(state, Update.Disconnect)
    if state.ssl do
      :ssl.shutdown(state.socket, :write)
    else
      :gen_tcp.shutdown(state.socket, :write)
    end
    %{state | state: :closed}
  end

  def data(connection) do
    if self() == connection do
      raise "Can't request own data."
    end
    send connection, {:get_data, self()}
      receive do
        {:data, data} -> data
      end
  end

  def data(state, connection) do
    if self() == connection do
      state
    else
      data(connection)
    end
  end

  def write_sync(connection, update) do
    send(connection, {:send, update, self()}) 
    receive do
      {:sent, ^connection, ^update} -> :ok
    after 1_000 -> :timeout
    end
  end

  def remove_identity(connection) do
    send connection, {:DOWN, nil, :process, self(), :identity_removed}
  end

  def describe(state) do
    "#{inspect(self())}:#{Toolkit.ip(state.ip)}:#{state.name}"
  end

  def log(state, format) do
    Logger.info("#{describe(state)} #{format}")
  end
end
