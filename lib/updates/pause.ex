use Update
defupdate(Pause, "PAUSE", [:channel, :by]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        Channel.pause(channel, type.by)
        Channel.write(channel, update)
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
  end
end
