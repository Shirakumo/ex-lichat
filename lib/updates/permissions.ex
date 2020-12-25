use Update
defupdate(Permissions, "PERMISSIONS", [:channel, [:permissions, required: false]]) do
  def handle(type, update, state) do
    case Channel.get(Channel, type.channel) do
      {:ok, channel} ->
        if type.permissions != nil do
          Channel.update(channel, type.permissions)
        end
        Connection.write(state, Update.reply(update, Update.Permissions, [
                  from: Lichat.server_name(),
                  channel: type.channel,
                  permissions: Channel.permissions(channel)
                ]))
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
