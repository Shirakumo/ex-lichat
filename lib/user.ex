defmodule User do
  require Logger
  use GenServer
  defstruct name: nil, connections: %{}, channels: %{}, shares: %{}, blocked: MapSet.new()

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  defp generate_name() do
    suffix = for _ <- 1..8, into: ~c"", do: Enum.random(~c"abcdefghijklmnopqrstuvwxyz0123456789")
    IO.iodata_to_binary([ "Lichatter " | suffix ])
  end

  def random_name() do
    ## FIXME: This is bugged due to a race condition (the name is never reserved).
    Stream.repeatedly(&generate_name/0)
    |> Stream.filter(&(get(&1) == :error))
    |> Enum.fetch!(0)
  end
  
  def get(name) do
    case Registry.lookup(User, String.downcase(name)) do
      [] -> :error
      [{pid, _}] -> {:ok, pid}
    end
  end

  def list(:names), do: Registry.select(__MODULE__, [{{:"$1", :_, :_}, [], [{{:"$1", :"$1"}}]}])
  def list(:pids), do: Registry.select(__MODULE__, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])

  def ensure_user() do
    ensure_user(Lichat.server_name())
  end

  def ensure_user(name) do
    ## FIXME: Race condition here
    case Registry.lookup(__MODULE__, String.downcase(name)) do
      [] ->
        {:ok, pid} = Users.start_child([name])
        Logger.info("New user #{name} at #{inspect(pid)}")
        join(pid, Channel.primary())
        pid
      [{pid, _}] ->
        Logger.info("Existing user #{name} at #{inspect(pid)}")
        pid
    end
  end

  def connect(user, connection) do
    GenServer.cast(user, {:connect, connection})
    user
  end

  def disconnect(user, connection) do
    GenServer.cast(user, {:disconnect, connection})
    user
  end

  def join(user, channel) do
    GenServer.call(user, {:join, channel})
  end

  def leave(user, channel) do
    GenServer.cast(user, {:leave, channel})
    user
  end

  def write(user, update) do
    GenServer.cast(user, {:send, update})
    user
  end

  def write_sync(user, update) do
    GenServer.call(user, {:send, update})
  end

  def destroy(user) do
    GenServer.cast(user, :destroy)
    user
  end

  def create_share(user) when is_binary(user) do
    case User.get(user) do
      {:ok, user} -> create_share(user)
      :error -> :no_such_user
    end
  end
  
  def create_share(user) do
    GenServer.call(user, :create_share)
  end

  def revoke_share(user, key) when is_binary(user) do
    case User.get(user) do
      {:ok, user} -> revoke_share(user, key)
      :error -> :no_such_user
    end
  end

  def revoke_share(user, key) do
    GenServer.cast(user, {:revoke_share, key})
  end

  def revoke_all_shares(user) when is_binary(user) do
    case User.get(user) do
      {:ok, user} -> revoke_all_shares(user)
      :error -> :no_such_user
    end
  end

  def revoke_all_shares(user) do
    GenServer.cast(user, :revoke_all_shares)
  end

  def broadcast(user, data) do
    GenServer.cast(user, {:broadcast, data})
  end

  def broadcast(data) do
    Enum.each(list(:pids), fn user -> broadcast(user, data) end)
  end

  def assume(user, key) when is_binary(user) do
    case User.get(user) do
      {:ok, user} -> assume(user, key)
      :error -> :no_such_user
    end
  end
  
  def assume(user, key) do
    GenServer.call(user, {:assume, key})
  end
  
  def block(user, target) when is_binary(user) do
    {:ok, user} = User.get(user)
    block(user, target)
  end

  def block(user, target) do
    GenServer.cast(user, {:block, target})
    user
  end

  def unblock(user, target) when is_binary(user) do
    {:ok, user} = User.get(user)
    unblock(user, target)
  end

  def unblock(user, target) do
    GenServer.cast(user, {:unblock, target})
    user
  end

  def name(user) do
    GenServer.call(user, :name)
  end

  def channels(user) do
    GenServer.call(user, :channels)
  end

  def connections(user) do
    GenServer.call(user, :connections)
  end

  def data(user) do
    GenServer.call(user, :data)
  end

  def in_channel?(user, channel) do
    GenServer.call(user, {:in_channel?, channel})
  end

  @impl true
  def init(name) do
    {:ok, _} = Registry.register(__MODULE__, String.downcase(name), nil)
    blocked = case Profile.blocked(name) do
                :not_registered -> MapSet.new()
                map -> map
              end
    {:ok, %User{name: name, blocked: blocked}}
  end

  @impl true
  def handle_call(:name, _from, user) do
    {:reply, user.name, user}
  end

  @impl true
  def handle_call(:channels, _from, user) do
    {:reply, user.channels, user}
  end

  @impl true
  def handle_call(:connections, _from, user) do
    {:reply, user.connections, user}
  end

  @impl true
  def handle_call(:data, _from, user) do
    {:reply, user, user}
  end

  @impl true
  def handle_call({:in_channel?, channel}, _from, user) do
    {:reply, Map.has_key?(user.channels, channel), user}
  end

  @impl true
  def handle_call({:join, from}, _from, user) do
    cond do
      Toolkit.config(:max_channels_per_user) <= map_size(user.channels) ->
        {:reply, :too_many_channels, user}
      Map.has_key?(user.channels, from) ->
        {:reply, :already_in_channel, user}
      true ->
        ref = Process.monitor(from)
        Channel.join(from, {self(), user.name})
        {:reply, :ok, %{user | channels: Map.put(user.channels, from, {ref, Channel.name(from)})}}
    end
  end

  @impl true
  def handle_call(:create_share, _from, user) do
    if map_size(user.shares) < Toolkit.config(:max_shares_per_user) do
      key = Toolkit.random_key()
      {:reply, {:ok, key}, %{user | shares: Map.put(user.shares, key, :unclaimed)}}
    else
      {:reply, :too_many_shares, user}
    end
  end

  @impl true
  def handle_call({:assume, key, on_behalf}, from, user) do
    case Map.get(user.shares, key) do
      :unclaimed ->
        monitor = Process.monitor(from)
        shares = user.shares
        |> Map.put(key, {on_behalf, from})
        |> Map.put(from, {monitor, key})
        {:reply, {:ok, self()}, %{user | shares: shares}}
      nil -> {:reply, :no_such_key, user}
      _ -> {:reply, :key_used, user}
    end
  end

  @impl true
  def handle_call({:send, update}, _from, user) do
    if not MapSet.member?(user.blocked, String.downcase(update.from)) do
      Enum.each(Map.keys(user.connections), &Lichat.Connection.write_sync(&1, update))
    end
    {:reply, :ok, user}
  end

  @impl true
  def handle_cast({:connect, from}, user) do
    ref = Process.monitor(from)
    {:noreply, %{user | connections: Map.put(user.connections, from, ref)}}
  end
  
  @impl true
  def handle_cast({:disconnect, from}, user) do
    handle_info({:DOWN, Map.get(user.connections, from), :process, from, :disconnect}, user)
  end

  @impl true
  def handle_cast({:leave, from}, user) do
    Channel.leave(from, self())
    {{ref, _name}, channels} = Map.pop(user.channels, from)
    Process.demonitor(ref)
    {:noreply, %{user | channels: channels}}
  end

  @impl true
  def handle_cast({:send, update}, user) do
    if not MapSet.member?(user.blocked, String.downcase(update.from)) do
      Enum.each(Map.keys(user.connections), fn connection -> send(connection, {:send, update}) end)
    end
    {:noreply, user}
  end

  @impl true
  def handle_cast({:broadcast, data}, user) do
    Enum.each(Map.keys(user.connections), fn connection -> send(connection, data) end)
    {:noreply, user}
  end

  @impl true
  def handle_cast(:destroy, user) do
    Enum.each(user.connections, fn connection -> send(connection, :close) end)
    {:stop, :normal, user}
  end

  @impl true
  def handle_cast({:revoke_share, key}, user) do
    case Map.pop(user.shares, key) do
      {nil, _} -> 
        {:noreply, user}
      {:unclaimed, shares} -> 
        {:noreply, %{user | shares: shares}}
      {{_on_behalf, connection}, shares} ->
        shares = case Map.pop(shares, connection) do
                   {nil, shares} -> 
                     shares
                   {{monitor, _key}, shares} -> 
                     Process.demonitor(monitor)
                     shares
                 end
        Lichat.Connection.remove_identity(connection)
        {:noreply, %{user | shares: shares}}
    end
  end
  
  @impl true
  def handle_cast(:revoke_all_shares, user) do
    Enum.each(user.shares, fn {key, _} ->
      if is_binary(key), do: handle_cast({:revoke_share, key}, user)
    end)
    {:noreply, %{user | shares: %{}}}
  end
  
  def handle_cast({:block, target}, user) do
    {:noreply, %{user | blocked: MapSet.put(user.blocked, String.downcase(target))}}
  end

  @impl true
  def handle_cast({:unblock, target}, user) do
    {:noreply, %{user | blocked: MapSet.delete(user.blocked, String.downcase(target))}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, user) do
    Process.demonitor(ref)
    cond do
      Map.has_key?(user.connections, pid) ->
        connections = Map.delete(user.connections, pid)
        if Enum.empty?(connections) do
          {:stop, :normal, user}
        else
          {:noreply, %{user | connections: connections}}
        end
      Map.has_key?(user.channels, pid) ->
        {{_ref, name}, channels} = Map.pop(user.channels, pid)
        User.write(self(), Update.make(Update.Leave, [
                  from: user.name,
                  channel: name ]))
        {:noreply, %{user | channels: channels}}
      Map.has_key?(user.shares, pid) ->
        {{_ref, key}, shares} = Map.pop(user.shares, pid)
        {:noreply, %{user | shares: Map.drop(shares, key)}}
    end
  end
  
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
