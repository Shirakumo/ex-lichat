use Update
defupdate(Leave, "LEAVE", [:channel]) do
  def handle(_type, update, state) do
    case Channel.check_access(state, update) do
      {:error, _} -> nil
      {:ok, channel} ->
        Channel.write(channel, update)
        User.leave(state.user, channel)
    end
    state
  end
end
