defmodule User do
  require Logger
  use GenServer
  defstruct name: nil, connections: %{}, channels: %{}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def ensure_user(registry, name) do
    ## FIXME: Race condition here
    case Registry.lookup(registry, name) do
      [] ->
        {:ok, pid} = User.start_link([registry: registry, name: name])
        Logger.info("New user at #{inspect(pid)}")
        pid
      [{pid, _}] ->
        Logger.info("Existing user at #{inspect(pid)}")
        pid
    end
  end

  def connect(user) do
    GenServer.cast(user, {:connect, self()})
  end

  def disconnect(user) do
    GenServer.cast(user, {:disconnect, self()})
  end

  def join(user) do
    GenServer.cast(user, {:join, self()})
  end

  def leave(user) do
    GenServer.cast(user, {:leave, self()})
  end

  def write(user, update) do
    GenServer.cast(user, {:send, update})
  end

  @impl true
  def init([registry: registry, name: name]) do
    {:ok, _} = Registry.register(registry, name, nil)
    {:ok, %User{name: name}}
  end

  @impl true
  def handle_call(:channels, _from, user) do
    {:reply, user.channels, user}
  end

  @impl true
  def handle_cast({:connect, from}, user) do
    ref = Process.monitor(from)
    {:noreply, %{user | connections: Map.put(user.connections, from, ref)}}
  end
  
  @impl true
  def handle_cast({:disconnect, from}, user) do
    Process.demonitor(Map.get(user.connections, from))
    connections = Map.delete(user.connections, from)
    if Enum.empty?(connections) do
      {:stop, "no more connections", %User{}}
    else
      {:noreply, %{user | connections: connections}}
    end
  end

  @impl true
  def handle_cast({:join, from}, user) do
    {:noreply, %{user | channels: [ from | user.channels]}}
  end

  @impl true
  def handle_cast({:leave, from}, user) do
    {:noreply, %{user | channels: List.delete(user.channels, from)}}
  end

  @impl true
  def handle_cast({:send, update}, user) do
    Enum.each(Map.keys(user.connections), fn connection -> send connection, update end)
    {:noreply, user}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, user) do
    connections = Map.delete(user.connections, pid)
    if Enum.empty?(connections) do
      {:stop, "no more connections", %User{}}
    else
      {:noreply, %{user | connections: connections, channels: Map.delete(user.channels, pid)}}
    end
  end
  
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
