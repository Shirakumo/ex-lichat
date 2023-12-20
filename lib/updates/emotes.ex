use Update
defupdate(Emotes, "EMOTES", [[:names, optional: true], [:channel, optional: true]]) do
  def handle(type, update, state) do
    channelname = if is_nil(type.channel), do: Lichat.server_name(), else: type.channel
    case Channel.get(channelname) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          names = if is_list(type.names), do: type.names, else: []
          emotes = Emote.list(channelname, names)
          Enum.each(emotes, fn emote ->
            Lichat.Connection.write(state, Update.reply(update, Update.Emote, [
                      from: Lichat.server_name(),
                      channel: channelname,
                      name: emote.name,
                          content_type: emote.type,
                      payload: emote.payload ]))
          end)
          Lichat.Connection.write(state, %{update | type: %{type | names: Enum.map(emotes, &Map.get(&1, :name))}})
        else
            Lichat.Connection.write(state, Update.fail(update, Update.NotInChannel,
                  [text: "#{update.from} is not in #{channelname}"]))
        end
      :error ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel,
              [text: "No such channel with the name #{channelname}"]))
    end
    state
  end
end
