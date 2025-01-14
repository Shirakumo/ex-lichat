use Update
defupdate(Permissions, "PERMISSIONS", [:channel, [:permissions, required: false]]) do
  require Logger
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        if type.permissions != nil do
          Logger.info("#{update.from} set permissions on #{type.channel}", [intent: :user])
          IpLog.record(state, Update.Permissions, type.channel)
          Channel.update(channel, type.permissions)
        end
        Lichat.Connection.write(state, Update.reply(update, Update.Permissions, [
                  from: Lichat.server_name(),
                  channel: type.channel,
                  permissions: Channel.permissions(channel)
                ]))
      :error ->
        Failure.no_such_channel(state, update)
    end
    state
  end
end
