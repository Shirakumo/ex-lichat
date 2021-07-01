use Update
defupdate(Join, "JOIN", [:channel]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        case User.join(state.user, channel) do
          :too_many_channels ->
            Lichat.Connection.write(state, Update.fail(update, Update.TooManyChannels))
          :already_in_channel ->
            Lichat.Connection.write(state, Update.fail(update, Update.AlreadyInChannel))
          :ok ->
            User.join(state.user, channel)
            Channel.last_read(channel, update.from, update.from, update.id)
            Channel.write(channel, update)
            pause = Channel.pause(channel)
            if 0 < pause, do: Lichat.Connection.write(state, Update.make(Pause, by: pause))
        end
      :error ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
