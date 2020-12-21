defmodule Emote do
  require Logger
  use Agent
  defstruct name: nil, type: nil, payload: nil

  def start_link(opts) do
    case Agent.start_link(fn -> %{} end, opts) do
      {:ok, pid} ->
        reload(pid)
        {:ok, pid}
      x -> x
    end
  end

  def reload(server) do
    Logger.info("Reloading emotes")
    case File.ls("emotes/") do
      {:ok, files} -> 
        emotes = Enum.map(files, &load_emote(&1))
        Agent.update(server, fn(_) -> emotes end)
        emotes
      {:error, reason} ->
        error = :file.format_error(reason)
        Logger.error("Failed to reload emotes: #{error}")
        []
    end
  end

  def list(server) do
    case Agent.get(server, &(&1)) do
      {:ok, emotes} -> emotes
      :error -> reload(server)
    end
  end

  def load_emote(file) do
    case File.read(file) do
      {:ok, content} ->
        %Emote{
          name: Path.basename(file),
          type: MIME.from_path(file),
          payload: Base.encode64(content)}
      {:error, reason} ->
        error = :file.format_error(reason)
        Logger.error("Failed to load emote #{file}: #{error}")
    end
  end
end
