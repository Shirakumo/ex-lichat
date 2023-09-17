defmodule Channel do
  require Logger
  use GenServer
  defstruct name: nil,
    registrant: nil,
    permissions: %{},
    users: %{},
    meta: %{},
    lifetime: Toolkit.config(:channel_lifetime),
    expiry: nil,
    pause: 0,
    last_update: %{},
    quiet: MapSet.new(),
    last_read: %{}

  def default_channel_permissions, do: Map.new([
        {Update.Backfill, true},
        {Update.Bridge, :registrant},
        {Update.Capabilities, true},
        {Update.ChannelInfo, true},
        {Update.Channels, true},
        {Update.Create, :registrant},
        {Update.Data, true},
        {Update.Deny, :registrant},
        {Update.Destroy, :registrant},
        {Update.Edit, true},
        {Update.Emote, :registrant},
        {Update.Emotes, true},
        {Update.Grant, :registrant},
        {Update.Join, true},
        {Update.Kick, :registrant},
        {Update.LastRead, true},
        {Update.Leave, true},
        {Update.Message, true},
        {Update.Pause, :registrant},
        {Update.Permissions, :registrant},
        {Update.Pull, true},
        {Update.Quiet, :registrant},
        {Update.Quieted, :registrant},
        {Update.React, true},
        {Update.Search, true},
        {Update.SetChannelInfo, :registrant},
        {Update.Typing, true},
        {Update.Unquiet, :registrant},
        {Update.Users, true},
      ])

  def default_anonymous_channel_permissions, do: Map.new([
        {Update.Backfill, false},
        {Update.Bridge, :registrant},
        {Update.Capabilities, true},
        {Update.ChannelInfo, false},
        {Update.Channels, false},
        {Update.Data, true},
        {Update.Deny, false},
        {Update.Destroy, :registrant},
        {Update.Edit, true},
        {Update.Emote, false},
        {Update.Emotes, true},
        {Update.Grant, false},
        {Update.Join, false},
        {Update.Kick, :registrant},
        {Update.LastRead, false},
        {Update.Leave, true},
        {Update.Message, true},
        {Update.Pause, :registrant},
        {Update.Permissions, false},
        {Update.Pull, true},
        {Update.Quiet, :registrant},
        {Update.Quieted, :registrant},
        {Update.React, true},
        {Update.Search, false},
        {Update.SetChannelInfo, false},
        {Update.Typing, true},
        {Update.Unquiet, :registrant},
        {Update.Users, true},
      ])

  def default_primary_channel_permissions, do: Map.new([
        {Update.AssumeIdentity, true},
        {Update.Backfill, false},
        {Update.Ban, :registrant},
        {Update.Blacklist, :registrant},
        {Update.Block, true},
        {Update.Blocked, true},
        {Update.Bridge, :registrant},
        {Update.Capabilities, true},
        {Update.ChannelInfo, true},
        {Update.Channels, true},
        {Update.Connect, true},
        {Update.Create, true},
        {Update.Data, :registrant},
        {Update.Deny, :registrant},
        {Update.Destroy, :registrant},
        {Update.Disconnect, true},
        {Update.Edit, :registrant},
        {Update.Emote, :registrant},
        {Update.Emotes, true},
        {Update.Grant, :registrant},
        {Update.IpBan, :registrant},
        {Update.IpBlacklist, :registrant},
        {Update.IpUnban, :registrant},
        {Update.Join, true},
        {Update.Kick, :registrant},
        {Update.Kill, :registrant},
        {Update.LastRead, false},
        {Update.Leave, false},
        {Update.ListSharedIdentities, true},
        {Update.Message, :registrant},
        {Update.Pause, false},
        {Update.Permissions, :registrant},
        {Update.Ping, true},
        {Update.Pong, true},
        {Update.Pull, false},
        {Update.Quiet, false},
        {Update.Quieted, false},
        {Update.React, true},
        {Update.Register, true},
        {Update.Search, true},
        {Update.ServerInfo, :registrant},
        {Update.SetChannelInfo, :registrant},
        {Update.SetUserInfo, true},
        {Update.ShareIdentity, false},
        {Update.Typing, false},
        {Update.Unban, :registrant},
        {Update.Unblock, true},
        {Update.Unquiet, false},
        {Update.UserInfo, true},
        {Update.Users, true},
      ])

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get(name) do
    case Registry.lookup(__MODULE__, String.downcase(name)) do
      [] -> :error
      [{pid, _}] -> {:ok, pid}
    end
  end

  def primary() do
    {:ok, primary} = get(Lichat.server_name())
    primary
  end

  def make(registrant) do
    channel = %Channel{
      name: anonymous_name(),
      registrant: Lichat.server_name(),
      permissions: evaluate_permissions(default_anonymous_channel_permissions(), registrant),
      lifetime: 1}
    case Channels.start_child([channel]) do
      {:ok, pid} -> {channel.name, pid}
      ## Not great...
      _ -> make(registrant)
    end
  end

  def ensure_channel() do
    ensure_channel(%Channel{
          name: Lichat.server_name(),
          registrant: Lichat.server_name(),
          permissions: evaluate_permissions(default_primary_channel_permissions(), Lichat.server_name()),
          lifetime: nil})
  end

  def ensure_channel(name, registrant) do
    ensure_channel(%Channel{
          name: name,
          registrant: registrant,
          permissions: evaluate_permissions(default_channel_permissions(), registrant)})
  end

  def ensure_channel(channel) do
    ## FIXME: Race condition here
    case Registry.lookup(Channel, String.downcase(channel.name)) do
      [] ->
        {:ok, pid} = Channels.start_child([channel])
        History.create(channel.name)
        Logger.info("New channel #{channel.name} at #{inspect(pid)}")
        {:new, pid}
      [{pid, _}] ->
        {:old, pid}
    end
  end

  def valid_info?(symbol) do
    Symbol.is_symbol(symbol)
    and symbol.package == :keyword
    and Enum.member?(["TITLE", "NEWS", "TOPIC", "RULES", "CONTACT", "ICON", "URL"], symbol.name)
  end

  def valid_info?(symbol, value) do
    Toolkit.valid_info?(symbol, value)
  end

  def list(:names), do: Registry.select(__MODULE__, [{{:"$1", :_, :_}, [], [{{:"$1", :"$1"}}]}])
  def list(:pids), do: Registry.select(__MODULE__, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])

  def list(parent, kind \\ :names) do
    if is_binary(parent) and parent != "" do
      parent = parent <> "/"
      Enum.filter(list(kind), fn {name, _val} -> String.starts_with?(name, parent) end)
    else
      Enum.reject(list(kind), fn {name, _val} -> String.contains?(name, "/") end)
    end
  end

  def join(channel, {user, name}) do
    GenServer.call(channel, {:join, user, name})
    channel
  end
  
  def leave(channel, user) do
    GenServer.cast(channel, {:leave, user})
    channel
  end

  def write(channel, update) when is_binary(channel) do
    {:ok, channel} = Channel.get(channel)
    write(channel, update)
  end
  def write(channel, update) do
    GenServer.cast(channel, {:send, update})
    History.record(update)
    channel
  end

  def write_sync(channel, update) do
    GenServer.call(channel, {:send, update})
  end

  def quiet(channel, user) when is_binary(channel) do
    {:ok, channel} = Channel.get(channel)
    quiet(channel, user)
  end
  def quiet(channel, user) when is_binary(user) do
    GenServer.cast(channel, {:quiet, user})
    channel
  end

  def unquiet(channel, user) when is_binary(channel) do
    {:ok, channel} = Channel.get(channel)
    unquiet(channel, user)
  end
  def unquiet(channel, user) when is_binary(user) do
    GenServer.cast(channel, {:unquiet, user})
    channel
  end

  def pause(channel) do
    GenServer.call(channel, :pause)
  end

  def pause(channel, pause) when is_binary(channel) do
    {:ok, channel} = Channel.get(channel)
    pause(channel, pause)
  end
  def pause(channel, pause) do
    GenServer.cast(channel, {:pause, pause})
    channel
  end
  
  def update(channel, permissions) when is_binary(channel) do
    {:ok, channel} = Channel.get(channel)
    update(channel, permissions)
  end
  def update(channel, permissions) do
    GenServer.cast(channel, {:permissions, permissions})
    channel
  end

  def grant(channel, user, update) when is_binary(channel) do
    {:ok, channel} = Channel.get(channel)
    grant(channel, user, update)
  end
  def grant(channel, user, update) do
    GenServer.cast(channel, {:grant, user, update})
    channel
  end

  def deny(channel, user, update) when is_binary(channel) do
    {:ok, channel} = Channel.get(channel)
    deny(channel, user, update)
  end
  def deny(channel, user, update) do
    GenServer.cast(channel, {:deny, user, update})
    channel
  end

  def destroy(channel) when is_binary(channel) do
    {:ok, channel} = Channel.get(channel)
    destroy(channel)
  end
  def destroy(channel) do
    GenServer.cast(channel, :destroy)
    channel
  end

  def permitted?(channel, update) when is_binary(channel) do
    case Channel.get(channel) do
      {:ok, channel} -> permitted?(channel, update)
      :error -> :no_such_channel
    end
  end

  def permitted?(channel, update) do
    GenServer.call(channel, {:permitted?, update.type.__struct__, update.from})
  end

  def permitted?(channel, type, user) do
    GenServer.call(channel, {:permitted?, type, user})
  end

  def last_read(channel, user) do
    GenServer.call(channel, {:last_read, user})
  end

  def last_read(channel, user, from, id) do
    GenServer.cast(channel, {:last_read, user, from, id})
    channel
  end

  def name(channel) do
    GenServer.call(channel, :name)
  end
  
  def users(channel) do
    GenServer.call(channel, :users)
  end

  def quieted(channel) do
    GenServer.call(channel, :quieted)
  end

  def usernames(channel) do
    GenServer.call(channel, :usernames)
  end

  def permissions(channel) when is_binary(channel) do
    case Channel.get(channel) do
      {:ok, channel} -> permissions(channel)
      :error -> :no_such_channel
    end
  end
  
  def permissions(channel) do
    GenServer.call(channel, :permissions)
  end

  def is_primary?(channel) when is_binary(channel) do
    # What the fuck is there no case insensitive compare op?
    String.downcase(channel) == String.downcase(Lichat.server_name)
  end

  def is_primary?(channel) do
    is_primary?(name(channel))
  end

  def parent(channel) when is_binary(channel) do
    case Regex.run(~r/^(.*)\//u, channel) do
      [_, name] -> name
      nil -> Lichat.server_name()
    end
  end

  def parent(channel) do
    get(parent(name(channel)))
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

  def make_admin(channel, user) when is_binary(channel) do
    {:ok, channel} = Channel.get(channel)
    make_admin(channel, user)
  end
  def make_admin(channel, user) do
    Enum.each(default_channel_permissions(), fn {type, rule} ->
      if rule == :registrant do
        grant(channel, user, type)
      end
    end)
  end
  def make_admin(user) do
    channel = primary()
    Enum.each(default_primary_channel_permissions(), fn {type, rule} ->
      if rule == :registrant do
        grant(channel, user, type)
      end
    end)
  end
  
  @impl true
  def init(channel) do
    lifetime = channel.lifetime
    registrant = Map.get(channel, :registrant, Lichat.server_name())
    def_permissions = if registrant == Lichat.server_name() do
      evaluate_permissions(default_primary_channel_permissions(), registrant)
    else
      evaluate_permissions(default_channel_permissions(), registrant)
    end
    {:ok, _} = Registry.register(__MODULE__, String.downcase(channel.name), nil)
    {:ok, timer} = if lifetime == nil, do: {:ok, nil}, else: :timer.send_after(lifetime * 1000, :expire)
    {:ok, %Channel{
        name: channel.name,
        registrant: registrant,
        permissions: Map.merge(def_permissions, channel.permissions),
        users: %{},
        meta: Map.get(channel, :meta, %{}),
        lifetime: lifetime,
        expiry: timer,
        pause: Map.get(channel, :pause, 0),
        last_update: %{},
        quiet: Map.get(channel, :quiet, MapSet.new())
     }}
  end
  
  @impl true
  def handle_cast({:leave, from}, channel) do
    {{_name, ref, _time}, users} = Map.pop(channel.users, from)
    Process.demonitor(ref)
    if Enum.empty?(users) and channel.lifetime != nil do
      {:ok, timer} = :timer.send_after(channel.lifetime * 1000, :expire)
      {:noreply, %{channel | users: users, expiry: timer}}
    else
      {:noreply, %{channel | users: users}}
    end
  end

  @impl true
  def handle_cast({:send, update}, channel) do
    if MapSet.member?(channel.quiet, String.downcase(update.from)) do
      Enum.each(Map.keys(channel.users), fn user ->
        if User.name(user) == update.from do
          User.write(user, update)
        end
      end)
    else
      Enum.each(Map.keys(channel.users), &User.write(&1, update))
    end
    {:noreply,
     %{channel |
       last_update: if 0 < channel.pause do
         Map.put(channel.last_update, String.downcase(update.from), Toolkit.universal_time())
       else
         channel.last_update
       end
     }}
  end

  @impl true
  def handle_cast({:quiet, user}, channel) do
    {:noreply, %{channel | quiet: MapSet.put(channel.quiet, String.downcase(user)) }}
  end

  @impl true
  def handle_cast({:unquiet, user}, channel) do
    {:noreply, %{channel | quiet: MapSet.delete(channel.quiet, String.downcase(user)) }}
  end

  @impl true
  def handle_cast({:pause, pause}, channel) do
    if pause <= 0 do
      {:noreply, %{channel | pause: 0, last_update: %{}}}
    else
      {:noreply, %{channel | pause: pause}}
    end
  end

  @impl true
  def handle_cast({:permissions, rules}, channel) do
    perms = Enum.into(rules, channel.permissions, fn [type, perm] ->
      {Update.ensure_type(type), compile_rule(perm)}
    end)
    {:noreply, %{channel | permissions: perms}}
  end

  @impl true
  def handle_cast({:grant, user, update}, channel) do
    user = String.downcase(user)
    type = Update.ensure_type(update)
    rule = Map.get(channel.permissions, type, %{:default => true})
    rule = if Map.fetch!(rule, :default) do
      Map.delete(rule, user)
    else
      Map.put(rule, user, true)
    end
    {:noreply, %{channel | permissions: Map.put(channel.permissions, type, rule)}}
  end

  @impl true
  def handle_cast({:deny, user, update}, channel) do
    user = String.downcase(user)
    type = Update.ensure_type(update)
    rule = Map.get(channel.permissions, type, %{:default => true})
    rule = if Map.fetch!(rule, :default) do
      Map.put(rule, user, false)
    else
      Map.delete(rule, user)
    end
    {:noreply, %{channel | permissions: Map.put(channel.permissions, type, rule)}}
  end

  @impl true
  def handle_cast({:info, key, value}, channel) do
    {:noreply, %{channel | meta: Map.put(channel.meta, key, value)}}
  end

  @impl true
  def handle_cast(:destroy, channel) do
    Enum.each(channel.users, fn {user, {name, _}} ->
      User.write(user, Update.make(Update.Leave, [
                channel: channel.name,
                from: name ]))
    end)
    {:stop, :normal, channel}
  end

  @impl true
  def handle_cast({:last_read, user, from, id}, channel) do
    {:noreply, %{channel | last_read: Map.put(channel.last_read, String.downcase(user), {from, id})}}
  end

  @impl true
  def handle_call({:send, update}, _from, channel) do
    ## We duplicate handle_cast({:send ..}) here almost to the letter. This is bad, should factor out.
    if MapSet.member?(channel.quiet, String.downcase(update.from)) do
      Enum.each(Map.keys(channel.users), fn user ->
        if User.name(user) == update.from do
          User.write_sync(user, update)
        end
      end)
    else
      Enum.each(Map.keys(channel.users), &User.write(&1, update))
    end
    {:reply, :ok,
     %{channel |
       last_update: if 0 < channel.pause do
         Map.put(channel.last_update, String.downcase(update.from), Toolkit.universal_time())
       else
         channel.last_update
       end
     }}
  end
  
  @impl true
  def handle_call({:join, from, name}, _from, channel) do
    if Map.has_key?(channel.users, from) do
      channel
    else
      ref = Process.monitor(from)
      if channel.expiry != nil do
        :timer.cancel(channel.expiry)
      end
      {:reply, :ok, %{channel | users: Map.put(channel.users, from, {name, ref, Toolkit.universal_time()}), expiry: nil}}
    end
  end

  @impl true
  def handle_call({:permitted?, type, user}, _from, channel) do
    user = String.downcase(user)
    if 0 < channel.pause and (Toolkit.time() - Map.get(channel.last_update, user, 0)) < channel.pause do
      {:reply, :timeout, channel}
    else
      case Map.fetch(channel.permissions, type) do
        {:ok, rule} ->
          {:reply, Map.get_lazy(rule, user, fn -> Map.fetch!(rule, :default) end), channel}
        :error ->
          if channel.name == Lichat.server_name() do
            {:reply, false, channel}
          else
            {:reply, GenServer.call(Channel.primary(), {:permitted?, type, user}), channel}
          end
      end
    end
  end

  @impl true
  def handle_call(:name, _from, channel) do
    {:reply, channel.name, channel}
  end
  
  @impl true
  def handle_call(:users, _from, channel) do
    {:reply, Map.keys(channel.users), channel}
  end

  @impl true
  def handle_call(:quieted, _from, channel) do
    {:reply, MapSet.to_list(channel.quiet), channel}
  end

  @impl true
  def handle_call(:usernames, _from, channel) do
    {:reply, Enum.map(channel.users, fn {_, {name, _, _}} -> name end), channel}
  end

  @impl true
  def handle_call(:permissions, _from, channel) do
    {:reply, channel.permissions
    |> Enum.reject(fn {type, _} -> type == false end)
    |> Enum.map(fn {type, rule} -> [apply(type, :type_symbol, []), decompile_rule(rule)] end),
     channel}
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
  def handle_call(:data, _from, channel) do
    {:reply, channel, channel}
  end

  @impl true
  def handle_call(:pause, _from, channel) do
    {:reply, channel.pause, channel}
  end

  @impl true
  def handle_call({:last_read, user}, _from, channel) do
    {:reply, Map.get(channel.last_read, String.downcase(user)), channel}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, channel) do
    case Map.get(channel.users, pid) do
      {name, _ref, _join} ->
        {:noreply, channel} = handle_cast({:leave, pid}, channel)
        if not Enum.empty?(channel.users) do
          handle_cast({:send, Update.make(Update.Leave, [
                              from: name,
                              channel: channel.name
                            ])}, channel)
        else
          {:noreply, channel}
        end
      nil ->
        {:noreply, channel}
    end
  end

  @impl true
  def handle_info(:expire, channel) do
    Logger.info("Channel #{channel.name} at #{inspect(self())} expired.")
    History.clear(channel.name)
    Link.clear(channel.name)
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
      "+" -> Map.put(Map.new(names, fn n -> {String.downcase(n), true} end), :default, false)
      "-" -> Map.put(Map.new(names, fn n -> {String.downcase(n), false} end), :default, true)
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
    registrant = String.downcase(registrant)
    Map.new(permissions, fn {t, r} ->
      case r do
        true -> {t, %{:default => true}}
        false -> {t, %{:default => false}}
        :registrant -> {t, %{registrant => true, :default => false}}
      end
    end)
  end
end
