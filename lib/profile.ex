defmodule Profile do
  require Logger
  use Agent
  defstruct name: nil, password: nil, expiry: nil, hashed: false

  def start_link(opts) do
    case Agent.start_link(fn -> %{} end, opts) do
      {:ok, pid} ->
        reload(pid)
        {:ok, pid}
      x -> x
    end
  end

  def reload(server) do
    Logger.info("Reloading profiles")
    case File.read("profiles.dat") do
      {:ok, content} ->
        map = :erlang.binary_to_term(content)
        Agent.update(server, fn(_) -> map end)
      {:error, reason} ->
        error = :file.format_error(reason)
        Logger.error("Failed to load profiles: #{error}")
        {:error, reason}
    end
  end

  def offload(server) do
    File.write("profiles.dat", :erlang.term_to_binary(Agent.get(server, & &1)))
  end

  def lookup(server, name) do
    case Agent.get(server, &Map.fetch(&1, name)) do
      {:ok, profile} ->
        if Toolkit.time() < profile.expiry, do: {:ok, profile}, else: :expired
      :error ->
        :not_registered
    end
  end

  def check(server, profile) do
    case lookup(server, profile.name) do
      {:ok, value} ->
        profile = ensure_hashed(profile)
        if value.password == profile.password, do: :ok, else: :bad_password
      x -> x
    end
  end

  def check(server, name, password) do
    password = case password do
                 false -> nil
                 [] -> nil
                 x -> x
               end
    check(server, %Profile{name: name, password: password})
  end

  def register(server, profile) do
    profile = %{ensure_hashed(profile) | expiry: Toolkit.time()+Toolkit.config(:profile_lifetime, 60*60*24*365)}
    Agent.update(server, &Map.put(&1, profile.name, profile))
  end

  defp ensure_hashed(profile) do
    if profile.hashed, do: profile, else: %{profile | password: hash(profile.password || ""), hashed: true}
  end
  
  defp hash(password), do: :crypto.hash(:sha512, password)
end
