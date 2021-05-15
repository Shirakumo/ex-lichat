defmodule Link do

  defp hash(payload) do
    :crypto.hash(:sha256, payload)
    |> Base.encode16()
    |> String.downcase()
  end
  
  defp file_path(channel, content_type, payload) do
    [ ext | _ ] = MIME.extensions(content_type)
    "/#{channel}/#{hash(payload)}.#{ext}"
  end
  
  def save(channel, content_type, payload) do
    case Toolkit.config!(:data_directory) do
      nil -> :disabled
      directory ->
        if is_list(Toolkit.config(:allowed_content_types))
        and not Enum.member?(Toolkit.config(:allowed_content_types), content_type) do
          {:error, "Bad content type."}
        else
          suffix = file_path(channel, content_type, payload)
          path = directory <> suffix
          url = Toolkit.config!(:link_url_prefix) <> suffix
          if File.exists?(path) do
            {:ok, url}
          else
            case File.mkdir_p(Path.dirname(path)) do
              {:error, _} -> {:error, "Failure creating directory for file."}
              :ok ->
                case File.write(path, Base.decode64!(payload)) do
                  {:error, _} -> {:error, "Failure writing file."}
                  :ok -> {:ok, Toolkit.config!(:link_url_prefix) <> suffix}
                end
            end
          end
        end
    end
  end

  def delete(channel, name) do
    File.rm("#{Toolkit.config!(:data_directory)}/#{channel}/#{name}")
  end

  def clear(channel) do
    File.rm_rf("#{Toolkit.config!(:data_directory)}/#{channel}/")
  end
end
