use Update
defupdate(Users, "USERS", [:channel, [:users, required: false]]) do
  def handle(type, update, state) do
    case Channel.check_access(state, update) do
      {:error, _} -> nil
      {:ok, channel} ->
        users = Channel.usernames(channel)
        Lichat.Connection.write(state, Update.reply(update, Update.Users, [
                  channel: type.channel,
                  from: Lichat.server_name(),
                  users: users]))
    end
    state
  end
end
