defmodule Connection do
  use Task
  require Logger
  defstruct socket: nil, user: nil, name: nil, state: nil

  def start_link(socket) do
    :inet.setopts(socket, [active: true])
    Task.start_link(__MODULE__, :run, [%Connection{socket: socket}])
  end
  
  def run(state) do
    next_state =
    receive do
      {:tcp, socket, data} ->
        # TODO: Reconstruct full updates from partial data,
        #       skip on length exceed or broken update, etc.
        #       Check permissions for user
        state = %{state | socket: socket}
        Logger.info("> #{data}")
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

  def write(state, update) do
    :gen_tcp.send(state.socket, Update.print(update))
    state
  end
  
  def establish(state, update) do
    Logger.info("Connect #{inspect(update)}")
    user = User.connect(User.ensure_user(User, update.from), self())
    write(state, Update.reply(update, Update.Connect, [
              version: Lichat.version(),
              extensions: Lichat.extensions()]))
    %{state | state: :connected, user: user, name: update.from}
  end

  def close(state) do
    write(state, Update.make(Update.Disconnect, [
              from: Toolkit.config(:name)
            ]))
    :gen_tcp.shutdown(state.socket, :write)
    %{state | state: :closed}
  end
end
