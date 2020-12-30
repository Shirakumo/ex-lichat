defmodule Connection do
  use Task
  require Logger
  defstruct type: nil, socket: nil, user: nil, name: nil, state: nil, accumulator: <<>>

  @callback init(String.t, Map.t) :: {:ok, Map.t} | :error
  @callback handle_payload(Map.t, String.t, Integer.t) :: {:ok, String.t, Map.t} | {:more, Map.t}
  @callback write(Map.t, Map.t) :: Map.t
  @callback close(Map.t) :: Map.t

  def start_link(socket) do
    :inet.setopts(socket, [active: true])
    Task.start_link(__MODULE__, :run, [%Connection{socket: socket}])
  end
  
  def run(state) do
    next_state =
      receive do
      {:tcp, socket, data} ->
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
        
        case state.type.handle_payload(state, data, Toolkit.config(:max_update_size, 8388608)) do
          {:ok, update, state} ->
            handle_update(state, update)
          {:more, state} ->
            state
          {:error, reason, state} ->
            Logger.info("Handler failure: #{reason}")
            shutdown(state)
        end
      {:tcp_closed, _} ->
        Logger.info("TCP closed #{inspect(self())} #{inspect(state.user)}")
        %{state | state: :closed}
      {:tcp_error, _} ->
        Logger.info("TCP error #{inspect(self())} #{inspect(state.user)}")
        %{state | state: :closed}
      {:send, msg} ->
        write(state, msg)
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

  def handle_update(state, data) do
    ## TODO: throttling
    try do
      update = Update.parse(data)
      try do
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
            update = case update.from do
                       nil -> %{update | from: state.name}
                       _ -> update
                     end
            if update.from != state.name do
                write(state, Update.fail(update, Update.UsernameMismatch))
            else
              case Update.permitted?(update) do
                false -> write(state, Update.fail(update, Update.InsufficientPermissions))
                :timeout -> write(state, Update.fail(update, Update.TooManyUpdates))
                true -> Update.handle(update, state)
              end
            end
        end
      rescue
        e in RuntimeError ->
          write(state, Update.fail(update, Update.UpdateFailure, [text: e.message]))
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

  def init(data, state) do
    Enum.find_value([Websocket, RawTCP], nil, fn module ->
      case module.init(data, state) do
        {:ok, state} ->
          {:ok, {addr, port}} = :inet.peername(state.socket)
          Logger.info("New #{inspect(module)} connection from #{:inet_parse.ntoa(addr)}:#{port} at #{inspect(self())}")
          state
        :error -> nil
      end
    end)
  end

  def write(state, data) when is_binary(data) do
    :gen_tcp.send(state.socket, data)
    state
  end

  def write(state, data) do
    state.type.write(state, data)
  end

  def close(state) do
    state.type.close(state)
  end
  
  def establish(state, update) do
    user = User.connect(User.ensure_user(update.from), self())
    write(state, Update.reply(update, Update.Connect, [
              version: Lichat.version(),
              extensions: Lichat.extensions()]))
    Enum.each(User.channels(user), fn {_channel, {_ref, name}} ->
      write(state, Update.make(Update.Join, [
                from: update.from,
                channel: name ])) end)
    %{state | state: :connected, user: user, name: update.from}
  end

  def shutdown(state) do
    :gen_tcp.shutdown(state.socket, :write)
    %{state | state: :closed}
  end
end
