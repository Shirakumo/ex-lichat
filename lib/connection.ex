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
            init(data, state)
          else
            %{state | socket: socket}
          end
        
        case state.type.handle_payload(state, data, Toolkit.config(:max_update_size, 8388608)) do
          {:ok, update, state} ->
            handle_update(state, update)
          {:more, state} ->
            state
        end
      {:tcp_closed, _} ->
        Logger.info("TCP closed #{inspect(state.user)}")
        %{state | state: :closed}
      {:tcp_error, _} ->
        Logger.info("TCP error #{inspect(state.user)}")
        %{state | state: :closed}
      {:send, msg} ->
        write(state, msg)
    end
    run(next_state)
  end

  def handle_update(state, data) do
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
            cond do
              update.from != state.name ->
                write(state, Update.fail(update, Update.UsernameMismatch))
              not Update.permitted?(update) ->
                write(state, Update.fail(update, Update.InsufficientPermissions))
              true ->
                Update.handle(update, state)
            end
        end
      rescue
        e in RuntimeError ->
          write(state, Update.fail(update, Update.UpdateFailure, [text: e.message]))
      end
    rescue
      e in Error.ParseFailure ->
        write(state, Update.fail(Update.MalformedUpdate, e.message))
      e in Error.UnsupportedUpdate ->
        write(state, Update.fail(Update.InvalidUpdate, e.message))
      e in RuntimeError ->
        write(state, Update.fail(Update.Failure, e.message))
    end
  end

  def init(data, state) do
    Enum.find_value([Websocket, RawTCP], nil, fn module ->
      case module.init(data, state) do
        {:ok, state} ->
          Logger.info("New #{inspect(module)} connection")
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
    Logger.info("Connect #{inspect(update)}")
    user = User.connect(User.ensure_user(User, update.from), self())
    write(state, Update.reply(update, Update.Connect, [
              version: Lichat.version(),
              extensions: Lichat.extensions()]))
    Enum.each(User.channels(user), fn {channel, _} ->
      write(state, Update.make(Update.Join, [
                from: update.from,
                channel: Channel.name(channel) ])) end)
    %{state | state: :connected, user: user, name: update.from}
  end

  def shutdown(state) do
    :gen_tcp.shutdown(state.socket, :write)
    %{state | state: :closed}
  end
end
