use Update
defupdate(Create, "CREATE", [:channel]) do
  def handle(type, update, state) do
    case type.channel do
      nil ->
        {name, channel} = Channel.make(Channel)
        User.join(state.user, channel)
        Connection.write(state, Update.reply(update, Update.Join, [channel: name]))
      name ->
        case Channel.ensure_channel(Channel, name, update.from) do
          {:old, _} ->
            Connection.write(state, Update.fail(update, Update.ChannelnameTaken))
          {:new, channel} ->
            User.join(state.user, channel)
            Connection.write(state, Update.reply(update, Update.Join, [channel: name]))
        end
    end
    state
  end
end
