use Update
defupdate(Join, "JOIN", [:channel]) do
  def handle(type, update, state) do
    case Channel.get(Channel, type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          nil # Connection.write(state, %AlreadyInChannel)
        else
          User.join(state.user, channel)
          Channel.write(channel, update)
        end
      :error ->
        nil # Connection.write(state, %NoSuchChannel)
    end
    state
  end
end
