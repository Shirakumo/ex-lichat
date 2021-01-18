use Update
defupdate(Create, "CREATE", [:channel]) do
  def handle(type, update, state) do
    cond do
      type.channel in [false, nil, ""] ->
        {name, channel} = Channel.make(update.from)
        User.join(state.user, channel)
        Connection.write(state, Update.reply(update, Update.Join, [channel: name]))
      not Toolkit.valid_channel_name?(type.channel) ->
        Connection.write(state, Update.fail(update, Update.BadName))
      true ->
        case Channel.ensure_channel(type.channel, update.from) do
          {:old, _} ->
            Connection.write(state, Update.fail(update, Update.ChannelnameTaken))
          {:new, channel} ->
            User.join(state.user, channel)
            Connection.write(state, Update.reply(update, Update.Join, [channel: type.channel]))
        end
    end
    state
  end
end
