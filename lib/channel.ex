defmodule Channel do
  require Logger
  use GenServer
  defstruct name: nil, permissions: %{}, users: %{}, meta: %{}, expiry: 0
  
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

  def valid_info(symbol) do
    symbol.package == :keyword and Enum.member?(["NEWS", "TOPIC", "RULES", "CONTACT"], symbol.name)
  end

  def valid_info(symbol, value) do
    valid_info(symbol) and is_binary(value)
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
  
  def update(channel, permissions) do
    GenServer.cast(channel, {:permissions, permissions})
  end
  
  def users(channel) do
    GenServer.call(channel, :users)
  end
  
  def permissions(channel) do
    GenServer.call(channel, :permissions)
  end

  def info(channel) do
    GenServer.call(channel, :info)
  end

  def info(channel, key) do
    GenServer.call(channel, {:info, key})
  end

  def info(channel, key, value) do
    GenServer.cast(channel, {:info, key, value})
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
  def handle_cast({:permissions, rules}, channel) do
    perms = Enum.into(rules, channel.permissions, fn [type, perm] ->
      {type, compile_rule(perm)}
    end)
    {:noreply, %{channel | permissions: perms}}
  end

  @impl true
  def handle_cast({:info, key, value}, channel) do
    {:noreply, %{channel | meta: Map.put(channel.meta, key, value)}}
  end

  @impl true
  def handle_call(:users, _from, channel) do
    {:reply, channel.users, channel}
  end

  @impl true
  def handle_call(:permissions, _from, channel) do
    {:reply, Enum.map(channel.permissions, fn {type, rule} -> [type, decompile_rule(rule)] end), channel}
  end

  @impl true
  def handle_call(:info, _from, channel) do
    {:reply, channel.meta, channel}
  end

  @impl true
  def handle_call({:info, key}, _from, channel) do
    {:reply, channel.meta[key], channel}
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

  defp compile_rule(:true) do
    %{:default => true}
  end

  defp compile_rule(:false) do
    %{:default => false}
  end

  defp compile_rule([symbol | names]) do
    case symbol.name do
      "+" -> Map.put(Map.new(names, fn n -> {n, true} end), :default, false)
      "-" -> Map.put(Map.new(names, fn n -> {n, false} end), :default, true)
    end
  end

  defp decompile_rule(rule) do
    {default, rule} = Map.pop!(rule, :default)
    cond do
      Enum.count(rule) == 0 ->
        default
      default == true ->
        [Symbol.li("-") | Enum.map(rule, fn {k, _} -> k end)]
      true ->
        [Symbol.li("+") | Enum.map(rule, fn {k, _} -> k end)]
    end
  end
end
