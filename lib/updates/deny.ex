use Update
defupdate(Deny, "DENY", [:channel, :update, :target]) do
  require Logger
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        Logger.info("#{update.from} denied #{inspect(type.update)} for #{type.target} in #{type.channel}", [intent: :user])
        IpLog.record(state, Update.Permissions, type.channel)
        Channel.deny(channel, type.target, type.update)
        Lichat.Connection.write(state, update)
      :error ->
        Failure.no_such_channel(state, update)
    end
    state
  end
end
