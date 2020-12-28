defmodule User do
  require Logger
  use GenServer
  defstruct name: nil, connections: %{}, channels: %{}

  def start_link(_opts) do
    Registry.start_link(name: __MODULE__, keys: :unique)
  end

  defp generate_name() do
    suffix = for _ <- 1..8, into: '', do: Enum.random('abcdefghijklmnopqrstuvwxyz0123456789')
    IO.iodata_to_binary([ "Random User " | suffix ])
  end

  def random_name() do
    ["Lichatter", "Random Guy", "Randy", "Chatty", "Rando", "Hoot"]
    |> Stream.concat(Stream.repeatedly(&generate_name/0))
    |> Stream.filter(&(get(&1) == :error))
    |> Enum.fetch!(0)
  end
  
  def get(name) do
    case Registry.lookup(User, name) do
      [] -> :error
      [{pid, _}] -> {:ok, pid}
    end
  end

  def ensure_user() do
    ensure_user(Lichat.server_name())
  end

  def ensure_user(name) do
    ## FIXME: Race condition here
    case Registry.lookup(__MODULE__, name) do
      [] ->
        {:ok, pid} = GenServer.start_link(__MODULE__, [name: name])
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
    user
  end

  def leave(user, channel) do
    GenServer.cast(user, {:leave, channel})
    user
  end

  def write(user, update) do
    GenServer.cast(user, {:send, update})
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

  def in_channel?(user, channel) do
    GenServer.call(user, {:in_channel?, channel})
  end

  @impl true
  def init([name: name]) do
    {:ok, _} = Registry.register(__MODULE__, name, nil)
    {:ok, %User{name: name}}
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
  def handle_call({:in_channel?, channel}, _from, user) do
    {:reply, Map.has_key?(user.channels, channel), user}
  end

  @impl true
  def handle_call({:join, from}, _from, user) do
    ref = Process.monitor(from)
    Channel.join(from, self())
    {:reply, :ok, %{user | channels: Map.put(user.channels, from, {ref, Channel.name(from)})}}
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
    Enum.each(Map.keys(user.connections), fn connection -> send(connection, {:send, update}) end)
    {:noreply, user}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, user) do
    Process.demonitor(ref)
    cond do
      Map.has_key?(user.connections, pid) ->
        connections = Map.delete(user.connections, pid)
        if Enum.empty?(connections) do
          {:stop, {:shutdown, "no more connections"}, user}
        else
          {:noreply, %{user | connections: connections}}
        end
      Map.has_key?(user.channels, pid) ->
        {{_ref, name}, channels} = Map.pop(user.channels, pid)
        User.write(self(), Update.make(Update.Leave, [
                  from: user.name,
                  channel: name ]))
        {:noreply, %{user | channels: channels}}
    end
  end
  
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
