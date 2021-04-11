use Update
defupdate(Users, "USERS", [:channel, [:users, required: false]]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          users = Channel.usernames(channel)
          Lichat.Connection.write(state, Update.reply(update, Update.Users, [
                    channel: type.channel,
                    from: Lichat.server_name(),
                    users: users]))
        else
          Lichat.Connection.write(state, Update.fail(update, Update.NotInChannel))
        end
      :error ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
