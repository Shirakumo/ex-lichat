defmodule User do
  require Logger
  use GenServer
  defstruct name: nil, connections: %{}, channels: %{}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  def get(registry, name) do
    case Registry.lookup(registry, name) do
      [] -> :error
      [{pid, _}] -> {:ok, pid}
    end
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

  def connect(user, connection) do
    GenServer.cast(user, {:connect, connection})
  end

  def disconnect(user, connection) do
    GenServer.cast(user, {:disconnect, connection})
  end

  def join(user, channel) do
    GenServer.cast(user, {:join, channel})
  end

  def leave(user, channel) do
    GenServer.cast(user, {:leave, channel})
  end

  def write(user, update) do
    GenServer.cast(user, {:send, update})
  end

  def channels(user) do
    GenServer.call(user, :channels)
  end

  def in_channel?(user, channel) do
    GenServer.call(user, {:in_channel?, channel})
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
  def handle_call({:in_channel?, channel}, _from, user) do
    {:reply, Map.has_key?(user.channels, channel)}
  end

  @impl true
  def handle_cast({:connect, from}, user) do
    ref = Process.monitor(from)
    {:noreply, %{user | connections: Map.put(user.connections, from, ref)}}
  end
  
  @impl true
  def handle_cast({:disconnect, from}, user) do
    handle_info({:down, Map.get(user.connections, from), :process, from, :disconnect}, user)
  end

  @impl true
  def handle_cast({:join, from}, user) do
    ref = Process.monitor(from)
    Channel.join(from)
    {:noreply, %{user | channels: Map.put(user.channels, from, ref)}}
  end

  @impl true
  def handle_cast({:leave, from}, user) do
    Channel.leave(from)
    handle_info({:down, Map.get(user.channels, from), :process, from, :disconnect}, user)
  end

  @impl true
  def handle_cast({:send, update}, user) do
    Enum.each(Map.keys(user.connections), fn connection -> send connection, update end)
    {:noreply, user}
  end

  @impl true
  def handle_info({:down, ref, :process, pid, _reason}, user) do
    Process.demonitor(ref)
    connections = Map.delete(user.connections, pid)
    channels = Map.delete(user.channels, pid)
    if Enum.empty?(connections) or Enum.empty?(channels) do
      {:stop, {:shutdown, "no more connections"}, %User{}}
    else
      {:noreply, %{user | connections: connections, channels: channels}}
    end
  end
  
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
