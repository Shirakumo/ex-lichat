defmodule Channels do
  use DynamicSupervisor
  require Logger

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    Registry.start_link(name: Channel, keys: :unique)
    ## Persist channels every hour.
    :timer.apply_interval(60 * 60 * 1000, Channels, :offload, [])
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def terminate(_, _) do
    offload()
    :normal
  end

  def start_child(opts) do
    DynamicSupervisor.start_child(__MODULE__, %{id: Channel, start: {Channel, :start_link, opts}, restart: :transient})
  end

  def reload() do
    Logger.info("Reloading channels")
    case File.read(Toolkit.config(:channel_file)) do
      {:ok, content} ->
        Enum.each(:erlang.binary_to_term(content), fn channel ->
          Channel.ensure_channel(channel)
        end)
        :ok
      {:error, reason} ->
        error = :file.format_error(reason)
        Logger.error("Failed to load channels: #{error}")
        {:error, error}
    end
  end

  def offload() do
    Logger.info("Persisting channels")
    channels = Enum.map(Channel.list(:pids), fn {_, channel} -> %{ Channel.data(channel) | users: %{}, expiry: nil} end)
    File.write(Toolkit.config(:channel_file), :erlang.term_to_binary(channels))
  end
end
