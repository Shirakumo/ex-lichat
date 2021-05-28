use Update
defupdate(Create, "CREATE", [[:channel, required: false]]) do
  require Logger
  def handle(type, update, state) do
    cond do
      type.channel in [false, nil, ""] ->
        {name, channel} = Channel.make(update.from)
        case User.join(state.user, channel) do
          :ok ->
            User.write(state.user, Update.reply(update, Update.Join, [channel: name]))
          :too_many_channels ->
            Lichat.Connection.write(state, Update.fail(update, Update.TooManyChannels))
        end
      not Toolkit.valid_channel_name?(type.channel) ->
        Lichat.Connection.write(state, Update.fail(update, Update.BadName))
      Toolkit.config!(:max_channels_per_user) <= map_size(User.channels(state.user)) ->
        Lichat.Connection.write(state, Update.fail(update, Update.TooManyChannels))
      true ->
        case Channel.ensure_channel(type.channel, update.from) do
          {:old, _} ->
            Lichat.Connection.write(state, Update.fail(update, Update.ChannelnameTaken))
          {:new, channel} ->
            Logger.info("#{update.from} created #{type.channel}", [intent: :user])
            case User.join(state.user, channel) do
              :ok ->
                User.write(state.user, Update.reply(update, Update.Join, [channel: type.channel]))
            end
        end
    end
    state
  end
end
