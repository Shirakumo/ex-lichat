defmodule Emote do
  require Logger
  use Agent
  defstruct name: nil, type: nil, payload: nil

  def start_link(opts) do
    case Agent.start_link(fn -> :error end, opts) do
      {:ok, pid} ->
        reload(pid)
        {:ok, pid}
      x -> x
    end
  end

  def reload(server) do
    Logger.info("Reloading emotes")
    dir = Toolkit.config(:emote_directory)
    case File.ls(dir) do
      {:ok, files} -> 
        emotes = Map.new(Enum.reject(Enum.map(files, &load_emote(dir <> &1)), &(&1 == nil)), &{&1.name, &1})
        Agent.update(server, fn _ -> emotes end)
        emotes
      {:error, reason} ->
        error = :file.format_error(reason)
        Logger.error("Failed to reload emotes: #{error}")
        %{}
    end
  end

  def list(server) do
    case Agent.get(server, &(&1)) do
      :error -> reload(server)
      emotes -> emotes
    end
  end

  def load_emote(file) do
    case File.read(file) do
      {:ok, content} ->
        name = Path.rootname(Path.basename(file))
        %Emote{
          name: name,
          type: MIME.from_path(file),
          payload: Base.encode64(content)}
      {:error, reason} ->
        Logger.error("Failed to load emote #{file}: #{:file.format_error(reason)}")
        nil
    end
  end
end
