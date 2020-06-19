defmodule Connection do
  use Task
  require Logger
  defstruct socket: nil, user: nil, state: nil

  defprotocol Executor do
    def handle(type, update, connection)
  end

  defimpl Executor, for: Updates.Connect do
    def handle(type, update, connection) do
      case connection.state do
        nil ->
          profile = %Profile{name: update.from, password: type.password}
          case Profile.check(Profile, profile) do
            :not_registered ->
              if type.password == nil do
                Connection.establish(connection, update)
              else
                # Connection.write(connection, %NoSuchProfile)
                Connection.close(connection)
              end
            :bad_password ->
              # Connection.write(connection, %InvalidPassword)
              Connection.close(connection)
            :ok ->
              Connection.establish(connection, update)
          end
        _ ->
          # Connection.write(connection, %AlreadyConnected)
          connection
      end
    end
  end

  defimpl Executor, for: Updates.Disconnect do
    def handle(type, update, connection) do
      Connection.close(connection)
    end
  end

  def start_link(socket) do
    :inet.setopts(socket, [active: true])
    Task.start_link(__MODULE__, :run, [%Connection{socket: socket}])
  end
  
  def run(state) do
    receive do
      {:tcp, socket, data} ->
        # TODO: Reconstruct full updates from partial data,
        #       skip on length exceed or broken update, etc.
        state = %{state | socket: socket}
        Logger.info("> #{data}")
        try do
          update = Update.parse(data)
          state = Executor.handle(update.type, update, state)
          run(state)
        rescue
          e in RuntimeError ->
            Logger.info("Error #{inspect(e)}")
            run(state)
        end
      {:tcp_closed, _} ->
        Logger.info("TCP closed")
        :done
      {:tcp_error, _} ->
        Logger.info("TCP error")
        :failed
      {:send, msg} ->
        write(state, msg)
        run(state)
    end
  end

  def write(state, update) do
    :gen_tcp.send(state.socket, Update.print(update))
  end
  
  def establish(state, update) do
    Logger.info("Connect #{inspect(update)}")
    User.connect(User.ensure_user(User, update.from))
    write(state, Update.reply(update, Updates.Connect, [
              version: Lichat.protocol_version(),
              extensions: Lichat.protocol_extensions()]))
    %{state | state: :connected}
  end

  def close(state) do
    write(state, Update.make(Updates.Disconnect, [
              from: Toolkit.config(:name)
            ]))
    :gen_tcp.shutdown(state.socket, :write)
    %{state | state: :closed}
  end
end
