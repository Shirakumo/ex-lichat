use Update
defupdate(Pause, "PAUSE", [:channel, :by]) do
  require Logger
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        Logger.info("#{update.from} paused #{type.channel} by #{type.by}", [intent: :user])
        Channel.pause(channel, type.by)
        Channel.write(channel, update)
      :error ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
