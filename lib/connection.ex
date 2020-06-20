defmodule Connection do
  use Task
  require Logger
  defstruct socket: nil, user: nil, state: nil

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
          run(Update.handle(Update.parse(data), state))
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
    User.connect(User.ensure_user(User, update.from), self())
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
