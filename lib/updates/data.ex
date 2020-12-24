use Update
defupdate(Data, "DATA", [:channel, [:content_type, symbol: "CONTENT-TYPE"], :filename, :payload]) do
  def handle(type, update, state) do
    if is_list(Toolkit.config(:allowed_content_types)
          and not Enum.member?(Toolkit.config(:allowed_content_types), type.content_type)) do
      Connection.write(state, Update.fail(update, Update.BadContentType, [
                allowed_content_types: Toolkit.config(:allowed_content_types) ]))
    else
      case Channel.get(Channel, type.channel) do
        {:ok, channel} ->
          if User.in_channel?(state.user, channel) do
            Channel.write(channel, update)
          else
            Connection.write(state, Update.fail(update, Update.NotInChannel))
          end
        :error ->
          Connection.write(state, Update.fail(update, Update.NoSuchChannel))
      end
    end
    state
  end
end
