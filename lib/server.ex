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

  defp tcp_options(ip) do
    [:binary,
     ip: ip,
     packet: :raw,
     active: false,
     nodelay: true,
     keepalive: true,
     reuseaddr: true,
     backlog: 500]
  end

  defp start_listener([ip: ip, port: port, acceptors: acceptors], supervisor) do
    {:ok, socket} = :gen_tcp.listen(port, tcp_options(ip))
    Logger.info("Accepting connections on port #{inspect(ip)}:#{port}")
    Enum.map(1..acceptors, fn (i) ->
      Supervisor.child_spec({Task, fn -> accept(supervisor, socket) end}, id: {Task, i}, restart: :permanent)
    end)
  end

  defp start_listener([ip: ip, port: port, acceptors: acceptors, ssl: ssl_opts], supervisor) do
    {:ok, socket} = :ssl.listen(port, tcp_options(ip) ++ ssl_opts)
    Logger.info("Accepting SSL connections on port #{inspect(ip)}:#{port}")
    Enum.map(1..acceptors, fn (i) ->
      Supervisor.child_spec({Task, fn -> accept_ssl(supervisor, socket) end}, id: {Task, 1000+i}, restart: :permanent)
    end)
  end
  
  defp accept(supervisor, socket) do
    case :gen_tcp.accept(socket) do
      {:ok, client} ->
        case DynamicSupervisor.start_child(supervisor, {Lichat.Connection, [socket: client, ssl: false]}) do
          {:ok, pid} ->
            :gen_tcp.controlling_process(client, pid)
          {:error, error} ->
            Logger.error("Failed to start child for #{inspect(socket)}: #{inspect(error)}")
        end
      {:error, error} ->
        Logger.error("Failed to accept #{inspect(socket)}: #{inspect(error)}")
    end
    accept(supervisor, socket)
  end

  defp accept_ssl(supervisor, socket) do
    case :ssl.transport_accept(socket) do
      {:ok, client} ->
        case DynamicSupervisor.start_child(supervisor, {Lichat.Connection, [socket: client, ssl: true]}) do
          {:ok, pid}  ->
            :ssl.controlling_process(client, pid)
          {:error, error} ->
            Logger.error("Failed to start child for #{inspect(socket)}: #{inspect(error)}")
        end
      {:error, error} ->
        Logger.error("Failed to accept #{inspect(socket)}: #{inspect(error)}")
    end
    accept_ssl(supervisor, socket)
  end
end
