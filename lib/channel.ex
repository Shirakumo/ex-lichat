defmodule Channel do
  require Logger
  use GenServer
  defstruct name: nil, permissions: %{}, users: %{}, expiry: 0
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get(registry, name) do
    case Registry.lookup(registry, name) do
      [] -> :error
      [{pid, _}] -> {:ok, pid}
    end
  end

  def make(registry) do
    name = anonymous_name()
    case Channel.start_link([registry: registry, name: name]) do
      {:ok, pid} -> {name, pid}
      ## Not great...
      _ -> make(registry)
    end
  end

  def ensure_channel(registry, name) do
    ## FIXME: Race condition here
    case Registry.lookup(registry, name) do
      [] ->
        {:ok, pid} = Channel.start_link([registry: registry, name: name])
        Logger.info("New channel at #{inspect(pid)}")
        {:new, pid}
      [{pid, _}] ->
        Logger.info("Existing channel at #{inspect(pid)}")
        {:old, pid}
    end
  end

  def list(registry) do
    Registry.keys(registry, self())
  end

  def join(channel) do
    GenServer.cast(channel, {:join, self()})
  end
  
  def leave(channel) do
    GenServer.cast(channel, {:leave, self()})
  end
  
  def write(channel, update) do
    GenServer.cast(channel, {:send, update})
  end
  
  def users(channel) do
    GenServer.call(channel, :users)
  end
  
  def permissions(channel) do
    GenServer.call(channel, :permissions)
  end
  
  def update(channel, permissions) do
    GenServer.cast(channel, {:permissions, permissions})
  end
  
  @impl true
  def init([registry: registry, name: name]) do
    {:ok, _} = Registry.register(registry, name, nil)
    {:ok, %Channel{name: name}}
  end
  
  @impl true
  def handle_cast({:join, from}, channel) do
    ref = Process.monitor(from)
    {:noreply, %{channel | users: Map.put(channel.users, from, ref)}}
  end
  
  @impl true
  def handle_cast({:leave, from}, channel) do
    handle_info({:DOWN, Map.get(channel.users, from), :process, from, :disconnect}, channel)
  end

  @impl true
  def handle_cast({:send, update}, channel) do
    Enum.each(Map.keys(channel.users), &User.write(&1, update))
    {:noreply, channel}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, channel) do
    Process.demonitor(ref)
    users = Map.delete(channel.users, pid)
    if Enum.empty?(users) and expired?(channel) do
      {:stop, {:shutdown, "no more connections"}, %Channel{}}
    else
      {:noreply, %{channel | users: users}}
    end
  end
  
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp expired?(channel) do
    case channel.expiry do
      nil -> nil
      x -> Toolkit.time() < x
    end
  end

  defp anonymous_name() do
    <<?@>> <> Toolkit.hashid()
  end
end
