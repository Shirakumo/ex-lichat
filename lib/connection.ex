defmodule Connection do
  require Logger
  
  def serve(socket) do
    :inet.setopts(socket, [active: true])
    receive do
      {:tcp, socket, data} ->
        Logger.info("> #{data}")
        Server.distribute(data)
        serve(socket)
      {:tcp_closed, _} ->
        Logger.info("TCP closed")
        :done
      {:tcp_error, _} ->
        Logger.info("TCP error")
        :failed
      {:send, msg} ->
        :gen_tcp.send(socket, msg)
        serve(socket)
    end
  end
end
