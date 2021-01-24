use Update
defupdate(Create, "CREATE", [[:channel, required: false]]) do
  require Logger
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
            Logger.info("#{update.from} created #{type.channel}", [intent: :user])
            User.join(state.user, channel)
            Connection.write(state, Update.reply(update, Update.Join, [channel: type.channel]))
        end
    end
    state
  end
end
