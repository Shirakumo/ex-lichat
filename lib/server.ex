defmodule Server do
  require Logger
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init([listeners: listeners, supervisor: supervisor]) do
    children = Enum.concat(Enum.map(listeners, &start_listener(&1, supervisor)))
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp start_listener([ip: ip, port: port, acceptors: acceptors], supervisor) do
    tcp_options = [:binary,
                   ip: ip,
                   packet: :raw,
                   active: false,
                   nodelay: true,
                   keepalive: true,
                   reuseaddr: true,
                   backlog: 500]
    {:ok, socket} = :gen_tcp.listen(port, tcp_options)
    Logger.info("Accepting connections on port #{inspect(ip)}:#{port}")
    Enum.map(1..acceptors, fn (i) ->
      Supervisor.child_spec({Task, fn -> accept(supervisor, socket) end}, id: {Task, i})
    end)
  end

  defp accept(supervisor, socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = DynamicSupervisor.start_child(supervisor, {Connection, client})
    :gen_tcp.controlling_process(client, pid)
    accept(supervisor, socket)
  end
end
