defmodule Server do
  require Logger
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init([port: port]) do
    init([port: port, acceptors: 2])
  end
  
  def init([port: port, acceptors: acceptors]) do
    tcp_options = [:binary, 
                   packet: :raw,
                   active: false, 
                   nodelay: true, 
                   keepalive: true, 
                   reuseaddr: true,
                   backlog: 500]
    {:ok, socket} = :gen_tcp.listen(port, tcp_options)
    children = Enum.map(1..acceptors, fn (i) ->
      Supervisor.child_spec({Task, fn -> accept(socket) end}, id: {Task, i})
    end)
    
    Logger.info("Accepting connections on port #{port}")
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp accept(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Connection.Supervisor, 
      fn -> Connection.serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    accept(socket)
  end

  def distribute(msg) do
    distribute(msg, Task.Supervisor.children(Connection.Supervisor))
  end

  defp distribute(_msg, []) do end
  defp distribute(msg, [pid | tail]) do
    send pid, {:send, msg}
    distribute(msg, tail)
  end
end
