use Update
defupdate(Join, "JOIN", [:channel]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          Connection.write(state, Update.fail(update, Update.AlreadyInChannel))
        else
          User.join(state.user, channel)
          Channel.write(channel, update)
          pause = Channel.pause(channel)
          if 0 < pause, do: Connection.write(state, Update.make(Pause, by: pause))
        end
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
