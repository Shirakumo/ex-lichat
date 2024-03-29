defmodule LocalProfile do
  @behaviour Profile
  require Logger
  use Agent
  defstruct name: nil, password: nil, expiry: Toolkit.time()+Toolkit.config(:profile_lifetime, 60*60*24*365), info: %{}, blocked: MapSet.new()

  @impl Profile
  def start_link(opts) do
    case Agent.start_link(fn -> %{} end, opts) do
      {:ok, pid} ->
        :timer.apply_interval(60 * 60 * 1000, LocalProfile, :offload, [pid])
        reload(pid)
        {:ok, pid}
      x -> x
    end
  end

  @impl Profile
  def reload(server) do
    Logger.info("Reloading profiles")
    case File.read(Toolkit.config(:profile_file)) do
      {:ok, content} ->
        map = Map.new(:erlang.binary_to_term(content), fn {k, map} ->
          {k, map
          |> Map.put_new(:blocked, MapSet.new())
          |> Map.put_new(:info, %{})}
        end)
        Agent.update(server, fn(_) -> map end)
        :ok
      {:error, reason} ->
        error = :file.format_error(reason)
        Logger.error("Failed to load profiles: #{error}")
        {:error, error}
    end
  end

  def offload(server) do
    Logger.info("Persisting profiles")
    Toolkit.safe_write(Toolkit.config(:profile_file), :erlang.term_to_binary(Agent.get(server, & &1)))
  end

  defp update(server, name, fun) do
    Agent.update(server, fn map ->
      if Map.has_key?(map, name) do
        Map.update!(map, name, fun)
      else
        map
      end
    end)
  end

  def info(server, name) do
    case Agent.get(server, &Map.fetch(&1, name)) do
      {:ok, profile} -> profile.info
      :error -> :not_registered
    end
  end

  def info(server, name, key, value) do
    update(server, name, &%{&1 | info: Map.put(&1.info, key, value)})
  end

  def blocked(server, name) do
    case Agent.get(server, &Map.fetch(&1, name)) do
      {:ok, profile} -> profile.blocked
      :error -> :not_registered
    end
  end

  def block(server, name, target) do
    update(server, name, &%{&1 | blocked: MapSet.put(&1.blocked, target)})
  end

  def unblock(server, name, target) do
    update(server, name, &%{&1 | blocked: MapSet.delete(&1.blocked, target)})
  end

  def ensure(server, name) do
    Agent.update(server, fn map ->
      Map.put_new(map, name, %LocalProfile{name: name})
    end)
  end

  @impl Profile
  def lookup(server, name) do
    case Agent.get(server, &Map.fetch(&1, name)) do
      {:ok, profile} ->
        if Toolkit.time() < profile.expiry, do: {:ok, profile}, else: :expired
      :error ->
        :not_registered
    end
  end

  @impl Profile
  def check(server, name, password) do
    case lookup(server, name) do
      {:ok, value} ->
        if value.password == hash(password), do: :ok, else: :bad_password
      x -> x
    end
  end

  @impl Profile
  def register(server, name, password) do
    profile = %LocalProfile{name: name, password: hash(password)}
    Agent.update(server, &Map.put(&1, profile.name, profile))
    :ok
  end
  
  defp hash(password), do: :crypto.hash(:sha512, password)
end
