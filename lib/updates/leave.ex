use Update
defupdate(Leave, "LEAVE", [:channel]) do
  def handle(type, update, state) do
    case Channel.get(Channel, type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          Channel.write(channel, update)
          User.leave(state.user, channel)
        else
          nil # Connection.write(state, %NotInChannel)
        end
      :error ->
        nil # Connection.write(state, %NoSuchChannel)
    end
    state
  end
end
