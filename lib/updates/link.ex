use Update
defmodule Update.Link do
  @behaviour Update
  @impl Update
  def type_symbol, do: %Symbol{name: "LINK", package: :lichat}
  defstruct channel: nil, content_type: nil, filename: nil, payload: nil

  defimpl Update.Serialize, for: Update.Link do
    def to_list(type), do: [Symbol.kw("CHANNEL"), type.channel,
                            Symbol.kw("CONTENT-TYPE"), type.content_type,
                            Symbol.kw("FILENAME"), type.filename,
                            Symbol.kw("PAYLOAD"), type.payload]
    def from_list(_, args) do
      Update.from_list(%Update{},
        [:type, %Update.Link{
            channel: Update.getf!(args, "CHANNEL"),
            content_type: Update.getf!(args, "CONTENT_TYPE"),
            filename: Update.getf!(args, "FILENAME"),
            payload: Update.getf!(args, "PAYLOAD")}])
    end
  end

  defimpl Update.Execute, for: Update.Link do
    def handle(type, update, state) do
      if is_list(Toolkit.config(:allowed_content_types))
      and not Enum.member?(Toolkit.config(:allowed_content_types), type.content_type) do
        Lichat.Connection.write(state, Update.fail(update, Update.BadContentType, [
                  allowed_content_types: Toolkit.config(:allowed_content_types) ]))
      else
        case Channel.get(type.channel) do
          {:ok, channel} ->
            if User.in_channel?(state.user, channel) do
              Channel.write(channel, update)
            else
              Lichat.Connection.write(state, Update.fail(update, Update.NotInChannel))
            end
          :error ->
            Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel))
        end
      end
      state
    end
  end

  defp file_path(channel, content_type) do
    [ ext | _ ] = MIME.extensions(content_type)
    "/#{channel}/#{Toolkit.random_key()}.#{ext}"
  end

  def save(channel, content_type, payload) do
    suffix = file_path(channel, content_type)
    path = Toolkit.config!(:data_directory) <> suffix
    File.mkdir_p(Path.dirname(path))
    File.write(path, Base.decode64!(payload))
    Toolkit.config!(:link_url_prefix) <> suffix
  end

  def clear(channel) do
    File.rm_rf("#{Toolkit.config!(:data_directory)}/#{channel}/")
  end
end

