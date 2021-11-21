defmodule Emote do
  require Logger
  defstruct channel: nil, name: nil, type: nil, payload: nil

  def emote?(channel, name) do
    Enum.any?(Toolkit.config(:allowed_emote_content_types),
      fn type -> File.exists?(file_path(channel, name, type)) end)
  end

  def list(channel, excluded \\ []) do
    excluded = Enum.map(excluded, &String.downcase/1)
    Enum.flat_map(File.ls!("#{Toolkit.config!(:emote_directory)}/#{channel}/"), 
      fn file ->
        if Path.rootname(Path.basename(file)) in excluded do
          []
        else
          [load_emote(file)]
        end
      end)
  end

  def save(channel, name, content_type, payload) do
    case Toolkit.config!(:emote_directory) do
      nil -> {:error, "Disabled."}
      directory ->
        cond do
          is_list(Toolkit.config(:allowed_emote_content_types))
          and not Enum.member?(Toolkit.config(:allowed_emote_content_types), content_type) ->
            {:bad_content_type, Toolkit.config(:allowed_emote_content_types)}
        payload == nil or payload == "" ->
            delete(channel, name)
            :ok
        true ->
            path = directory <> file_path(channel, name, content_type)
            payload = Base.decode64!(payload)
            if Toolkit.config(:max_emote_size) < byte_size(payload) do
              :too_large
            else
              case File.mkdir_p(Path.dirname(path)) do
                {:error, _} -> {:error, "Failure creating directory for file."}
                :ok ->
                  case File.write(path, payload) do
                    {:error, _} -> {:error, "Failure writing file."}
                    :ok -> :ok
                  end
              end
            end
        end
    end
  end

  def delete(channel, name) do
    Enum.each(Toolkit.config(:allowed_emote_content_types),
      fn type -> File.rm(file_path(channel, name, type)) end)
  end

  def clear(channel) do
    File.rm_rf("#{Toolkit.config!(:emote_directory)}/#{channel}/")
  end

  defp load_emote(file) do
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
  
  defp file_path(channel, name, content_type) do
    [ ext | _ ] = MIME.extensions(content_type)
    "/#{String.downcase(channel)}/#{String.downcase(name)}.#{ext}"
  end
end
