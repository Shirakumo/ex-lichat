use Update
defupdate(Data, "DATA", [:channel, [:content_type, symbol: "CONTENT-TYPE"], :filename, :payload]) do
  require Logger
  def handle(type, update, state) do
    if is_list(Toolkit.config(:allowed_content_types))
    and not Enum.member?(Toolkit.config(:allowed_content_types), type.content_type) do
      Lichat.Connection.write(state, Update.fail(update, Update.BadContentType, [
                allowed_content_types: Toolkit.config(:allowed_content_types) ]))
    else
      case Channel.get(type.channel) do
        {:ok, channel} ->
          if User.in_channel?(state.user, channel) do
            case Link.save(type.channel, type.content_type, type.payload) do
              {:ok, url} ->
                Channel.write(channel, %{update | type: %Update.Message{channel: type.channel, text: url, link: type.content_type}})
              {:error, reason} ->
                Logger.warn("Failed to save data update as link: #{reason}")
                Channel.write(channel, update)
              :disabled ->
                Channel.write(channel, update)
            end
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
