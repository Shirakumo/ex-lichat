defmodule Channel do
  require Logger
  use GenServer
  defstruct name: nil, permissions: %{}, users: %{}, meta: %{}, lifetime: nil, expiry: nil

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

  def get(name) do
    case Registry.lookup(__MODULE__, name) do
      [] -> :error
      [{pid, _}] -> {:ok, pid}
    end
  end

  def primary() do
    {:ok, primary} = get(Lichat.server_name())
    primary
  end

  def make(registrant) do
    name = anonymous_name()
    case Channels.start_child([{name, evaluate_permissions(default_anonymous_channel_permissions(), registrant), %{}, 0}]) do
      {:ok, pid} -> {name, pid}
      ## Not great...
      _ -> make(registrant)
    end
  end

  def ensure_channel() do
    ensure_channel(Lichat.server_name(), evaluate_permissions(default_primary_channel_permissions(), Lichat.server_name()), %{}, nil)
  end

  def ensure_channel(name, registrant) when is_binary(registrant) do
    ensure_channel(name, evaluate_permissions(default_channel_permissions(), registrant))
  end

  def ensure_channel(name, permissions) do
    ## Default lifetime is about 2 months.
    ensure_channel(name, permissions, %{}, Toolkit.config(:channel_lifetime, 5184000))
  end

  def ensure_channel(name, permissions, meta, lifetime) do
    ## FIXME: Race condition here
    case Registry.lookup(Channel, name) do
      [] ->
        {:ok, pid} = Channels.start_child([{name, permissions, meta, lifetime}])
        Logger.info("New channel #{name} at #{inspect(pid)}")
        {:new, pid}
      [{pid, _}] ->
        {:old, pid}
    end
  end

  def valid_info(symbol) do
    symbol.package == :keyword and Enum.member?(["NEWS", "TOPIC", "RULES", "CONTACT"], symbol.name)
  end

  def valid_info(symbol, value) do
    valid_info(symbol) and is_binary(value)
  end

  def list(kind \\ :names) do
    case kind do
      :names -> Registry.select(__MODULE__, [{{:"$1", :_, :_}, [], [:"$1"]}])
      :pids -> Registry.select(__MODULE__, [{{:_, :"$1", :_}, [], [:"$1"]}])
      :values -> Registry.select(__MODULE__, [{{:_, :_, :"$1"}, [], [:"$1"]}])
    end
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
    case Channel.get(channel) do
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

  def data(channel) do
    GenServer.call(channel, :data)
  end
  
  @impl true
  def init({name, permissions, meta, lifetime}) do
    {:ok, _} = Registry.register(__MODULE__, name, nil)
    {:ok, timer} = if lifetime == nil, do: {:ok, nil}, else: :timer.send_after(lifetime * 1000, :expire)
    {:ok, %Channel{name: name, permissions: permissions, meta: meta, lifetime: lifetime, expiry: timer}}
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
    if channel.expiry != nil do
      :timer.cancel(channel.expiry)
    end
    {:reply, :ok, %{channel | users: Map.put(channel.users, from, ref), expiry: nil}}
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
          {:reply, GenServer.call(Channel.primary(), {:permitted?, type, user}), channel}
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

  def handle_call(:data, _from, channel) do
    {:reply, channel, channel}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, channel) do
    Process.demonitor(ref)
    users = Map.delete(channel.users, pid)
    if Enum.empty?(users) and channel.lifetime != nil do
      {:ok, timer} = :timer.send_after(channel.lifetime * 1000, :expire)
      {:noreply, %{channel | users: users, expiry: timer}}
    else
      {:noreply, %{channel | users: users}}
    end
  end

  @impl true
  def handle_info(:expire, channel) do
    Logger.info("Channel #{channel.name} at #{inspect(self())} expired.")
    {:stop, :normal, channel}
  end
  
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
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
