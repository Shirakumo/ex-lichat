use Update
defupdate(Users, "USERS", [:channel]) do
  def handle(type, update, state) do
    case Channel.get(Channel, type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          Connection.write(state, Update.reply(update, Update.Users, [
                    from: Lichat.server_name(),
                    users: Channel.users(channel)]))
        else
          Connection.write(state, Update.fail(update, Update.NotInChannel))
        end
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
