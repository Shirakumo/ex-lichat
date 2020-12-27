defmodule Channel do
  require Logger
  use GenServer
  defstruct name: nil, permissions: %{}, users: %{}, meta: %{}, expiry: 0

  def default_channel_permissions, do: Map.new([
        {Update.Permissions, :registrant},
        {Update.Join, true},
        {Update.Leave, true},
        {Update.Kick, :registrant},
        {Update.Pull, true},
        {Update.Message, true},
        {Update.Users, true},
        {Update.Channels, true},
        {Update.Data, true},
        {Update.Edit, true},
        {Update.ChannelInfo, true},
        {Update.SetChannelInfo, :registrant}])

  def default_anonymous_channel_permissions, do: Map.new([
        {Update.Permissions, false},
        {Update.Join, false},
        {Update.Leave, true},
        {Update.Kick, :registrant},
        {Update.Pull, true},
        {Update.Message, true},
        {Update.Users, false},
        {Update.Channels, false},
        {Update.Data, true},
        {Update.Edit, true},
        {Update.ChannelInfo, false},
        {Update.SetChannelInfo, false}])

  def default_primary_channel_permissions, do: Map.new([
        {Update.Connect, true},
        {Update.Disconnect, true},
        {Update.Ping, true},
        {Update.Pong, true},
        {Update.Permissions, :registrant},
        {Update.Create, true},
        {Update.Join, true},
        {Update.Leave, false},
        {Update.Kick, :registrant},
        {Update.Pull, false},
        {Update.Message, :registrant},
        {Update.Users, true},
        {Update.Channels, true},
        {Update.Data, :registrant},
        {Update.Edit, :registrant},
        {Update.Emotes, true},
        {Update.Emote, :registrant},
        {Update.ChannelInfo, true},
        {Update.SetChannelInfo, :registrant}])
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get(registry, name) do
    case Registry.lookup(registry, name) do
      [] -> :error
      [{pid, _}] -> {:ok, pid}
    end
  end

  def primary(registry) do
    {:ok, primary} = get(registry, Lichat.server_name())
    primary
  end

  def make(registry) do
    name = anonymous_name()
    case Channel.start_link([registry: registry, name: name, permissions: default_anonymous_channel_permissions()]) do
      {:ok, pid} -> {name, pid}
      ## Not great...
      _ -> make(registry)
    end
  end

  def ensure_channel(registry) do
    ensure_channel(registry, Lichat.server_name(), evaluate_permissions(default_primary_channel_permissions(), Lichat.server_name()))
  end

  def ensure_channel(registry, name, registrant) when is_binary(registrant) do
    ensure_channel(registry, name, evaluate_permissions(default_channel_permissions(), registrant))
  end

  def ensure_channel(registry, name, permissions) do
    ## FIXME: Race condition here
    case Registry.lookup(registry, name) do
      [] ->
        {:ok, pid} = Channel.start_link([registry: registry, name: name, permissions: permissions])
        Logger.info("New channel #{name} at #{inspect(pid)}")
        {:new, pid}
      [{pid, _}] ->
        Logger.info("Existing channel #{name} at #{inspect(pid)}")
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
    Registry.select(registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  def join(channel, user) do
    GenServer.call(channel, {:join, user})
    channel
  end
  
  def leave(channel, user) do
    GenServer.cast(channel, {:leave, user})
    channel
  end
  
  def write(channel, update) do
    GenServer.cast(channel, {:send, update})
    channel
  end
  
  def update(channel, permissions) do
    GenServer.cast(channel, {:permissions, permissions})
    channel
  end

  def permitted?(channel, update) when is_binary(channel) do
    case Channel.get(Channel, channel) do
      {:ok, channel} -> permitted?(channel, update)
      :error -> true
    end
  end

  def permitted?(channel, update) do
    GenServer.call(channel, {:permitted?, update.type.__struct__, update.from})
  end

  def name(channel) do
    GenServer.call(channel, :name)
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
    channel
  end
  
  @impl true
  def init([registry: registry, name: name, permissions: permissions]) do
    {:ok, _} = Registry.register(registry, name, nil)
    {:ok, %Channel{name: name, permissions: permissions}}
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
    perms = Enum.into(rules, channel.permissions, fn [type_symbol, perm] ->
      {Update.find_type(type_symbol), compile_rule(perm)}
    end)
    {:noreply, %{channel | permissions: perms}}
  end

  @impl true
  def handle_cast({:info, key, value}, channel) do
    {:noreply, %{channel | meta: Map.put(channel.meta, key, value)}}
  end
  
  @impl true
  def handle_call({:join, from}, _from, channel) do
    ref = Process.monitor(from)
    {:reply, :ok, %{channel | users: Map.put(channel.users, from, ref)}}
  end

  @impl true
  def handle_call({:permitted?, type, user}, _from, channel) do
    case Map.fetch(channel.permissions, type) do
      {:ok, rule} ->
        {:reply, Map.get_lazy(rule, String.downcase(user), fn -> Map.fetch!(rule, :default) end), channel}
      :error ->
        if channel.name == Lichat.server_name() do
          {:reply, false, channel}
        else
          {:reply, GenServer.call(Channel.primary(Channel), {:permitted?, type, user}), channel}
        end
    end
  end

  @impl true
  def handle_call(:name, _from, channel) do
    {:reply, channel.name, channel}
  end
  
  @impl true
  def handle_call(:users, _from, channel) do
    {:reply, Enum.map(channel.users, fn {k, _} -> k end), channel}
  end

  @impl true
  def handle_call(:permissions, _from, channel) do
    {:reply, Enum.map(channel.permissions, fn {type, rule} -> [apply(type, :type_symbol, []), decompile_rule(rule)] end), channel}
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
    ## FIXME: We don't currently cull channels for expiry...
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

  defp compile_rule(true) do
    %{:default => true}
  end

  defp compile_rule(false) do
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
        [Symbol.li("-") | Enum.map(rule, fn {k, _} -> String.downcase(k) end)]
      true ->
        [Symbol.li("+") | Enum.map(rule, fn {k, _} -> String.downcase(k) end)]
    end
  end

  defp evaluate_permissions(permissions, registrant) do
    Map.new(permissions, fn {t, r} ->
      case r do
        true -> {t, %{:default => true}}
        false -> {t, %{:default => false}}
        :registrant -> {t, %{registrant => true, :default => false}}
      end
    end)
  end
end
