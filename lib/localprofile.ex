defmodule LocalProfile do
  @behaviour Profile
  require Logger
  use Agent
  defstruct name: nil, password: nil, expiry: nil

  @impl Profile
  def start_link(opts) do
    case Agent.start_link(fn -> %{} end, opts) do
      {:ok, pid} ->
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
        map = :erlang.binary_to_term(content)
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
    File.write(Toolkit.config(:profile_file), :erlang.term_to_binary(Agent.get(server, & &1)))
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
    profile = %LocalProfile{name: name, password: hash(password), expiry: Toolkit.time()+Toolkit.config(:profile_lifetime, 60*60*24*365)}
    Agent.update(server, &Map.put(&1, profile.name, profile))
    :ok
  end
  
  defp hash(password), do: :crypto.hash(:sha512, password)
end
