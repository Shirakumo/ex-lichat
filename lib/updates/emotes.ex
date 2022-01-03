use Update
defupdate(Emotes, "EMOTES", [:names, [:channel, optional: true]]) do
  def handle(type, update, state) do
    channelname = if is_nil(type.channel), do: Lichat.server_name(), else: type.channel
    case Channel.get(channelname) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
              Enum.each(Emote.list(channelname, type.names), fn emote ->
                Lichat.Connection.write(state, Update.reply(update, Update.Emote, [
                          from: Lichat.server_name(),
                          channel: channelname,
                          name: emote.name,
                          content_type: emote.type,
                          payload: emote.payload ]))
              end)
        else
          Lichat.Connection.write(state, Update.fail(update, Update.NotInChannel))
        end
      :error ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
