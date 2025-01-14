defmodule Emote do
  require Logger
  defstruct channel: nil, name: nil, type: nil, payload: nil

  def emote?(channel, name) do
    case Toolkit.config!(:emote_directory) do
      nil -> false
      directory ->
        found = Enum.any?(Toolkit.config(:allowed_emote_content_types),
        fn type -> File.exists?(directory <> file_path(channel, name, type)) end)
        cond do
          found -> true
          Channel.is_primary?(channel) -> false
          true -> emote?(Channel.parent(channel), name)
        end
    end
  end

  def list(channel, excluded \\ []) do
    excluded = Enum.map(excluded, &String.downcase/1)
    dir = "#{Toolkit.config!(:emote_directory)}/#{String.downcase(channel)}/"
    File.mkdir_p!(dir)
    Enum.flat_map(File.ls!(dir),
      fn file ->
        file = "#{dir}/#{file}"
        if Path.rootname(Path.basename(file)) in excluded do
          []
        else
          case load_emote(channel, file) do
            nil -> []
            emote -> [emote]
          end
        end
      end)
  end

  def save(channel, name, content_type, payload) do
    case file_path(channel, name, content_type) do
      {:error, e} -> {:error, e}
      path ->
        cond do
          is_list(Toolkit.config(:allowed_emote_content_types))
          and not Enum.member?(Toolkit.config(:allowed_emote_content_types), content_type) ->
            {:bad_content_type, Toolkit.config(:allowed_emote_content_types)}
          payload == nil or payload == "" ->
            delete(channel, name)
            :ok
          Toolkit.config(:max_emotes_per_channel) <= Enum.count(File.ls(Path.dirname(path))) ->
            :too_many_emotes
          true ->
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
    case Toolkit.config!(:emote_directory) do
      nil -> {:error, "Disabled."}
      directory ->
        Enum.each(Toolkit.config(:allowed_emote_content_types),
          fn type -> File.rm(directory <> file_path(channel, name, type)) end)
    end
  end

  def clear(channel) do
    case file_path(channel) do
      {:error, e} -> {:error, e}
      directory -> File.rm_rf(directory)
    end
  end

  defp load_emote(channel, file) do
    case File.read(file) do
      {:ok, content} ->
        name = Path.rootname(Path.basename(file))
        %Emote{
          name: name,
          channel: channel,
          type: MIME.from_path(file),
          payload: Base.encode64(content)}
      {:error, reason} ->
        Logger.error("Failed to load emote #{file}: #{:file.format_error(reason)}")
        nil
    end
  end

  defp file_path(channel) do
    case Toolkit.config!(:emote_directory) do
      nil -> {:error, "Disabled."}
      dir -> dir <> "/#{String.downcase(channel)}/"
    end
  end
  
  defp file_path(channel, name, content_type) do
    case Toolkit.config!(:emote_directory) do
      nil -> {:error, "Disabled."}
      dir ->
        [ ext | _ ] = MIME.extensions(content_type)
        dir <> "/#{String.downcase(channel)}/#{String.downcase(name)}.#{ext}"
    end
  end
end
