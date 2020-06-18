defmodule Connection do
  require Logger
  defstruct socket: nil, user: nil, state: nil

  defprotocol Executor do
    def handle(update, connection)
  end
  
  def serve(socket) do
    :inet.setopts(socket, [active: true])
    receive do
      {:tcp, socket, data} ->
        Logger.info("> #{data}")
        try do
          Executor.handle(Update.parse(data))
        rescue
          e in RuntimeError ->
            Logger.info("Error #{e}")
        end
        serve(socket)
      {:tcp_closed, _} ->
        Logger.info("TCP closed")
        :done
      {:tcp_error, _} ->
        Logger.info("TCP error")
        :failed
      {:send, msg} ->
        write(socket, msg)
        serve(socket)
    end
  end

  def write(socket, update) when is_struct(update) do
    :gen_tcp.send(socket, Update.print(update))
  end
end
