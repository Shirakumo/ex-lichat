use Update
defupdate(Join, "JOIN", [:channel]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        case User.join(state.user, channel) do
          :too_many_channels ->
            Lichat.Connection.write(state, Update.fail(update, Update.TooManyChannels,
                  [text: "#{update.from} is in too many channels (max #{Toolkit.config(:max_channels_per_user)})"]))
          :already_in_channel ->
            Lichat.Connection.write(state, Update.fail(update, Update.AlreadyInChannel,
                  [text: "#{update.from} is already in the channel #{type.channel}"]))
          :ok ->
            User.join(state.user, channel)
            Channel.last_read(channel, update.from, update.from, update.id)
            Channel.write(channel, update)
            pause = Channel.pause(channel)
            if 0 < pause, do: Lichat.Connection.write(state, Update.make(Pause, by: pause))
        end
      :error ->
        Failure.no_such_channel(state, update)
    end
    state
  end
end
