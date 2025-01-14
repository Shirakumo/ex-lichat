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
            Failure.too_many_channels(state, update)
        end
      not Toolkit.valid_channel_name?(type.channel) ->
        Lichat.Connection.write(state, Update.fail(update, Update.BadName,
              [text: "The channel name is illegal: #{type.channel}"]))
      Toolkit.config!(:max_channels_per_user) <= map_size(User.channels(state.user)) ->
        Failure.too_many_channels(state, update)
      true ->
        case Channel.ensure_channel(type.channel, update.from) do
          {:old, _} ->
            Lichat.Connection.write(state, Update.fail(update, Update.ChannelnameTaken,
                  [text: "The channel name is already taken: #{type.channel}"]))
          {:new, channel} ->
            IpLog.record(state, Update.Create)
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
