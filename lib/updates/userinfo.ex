use Update
defupdate(UserInfo, "USER-INFO", [:target]) do
  def handle(type, update, state) do
    connections = case User.get(User, type.target) do
                    {:ok, user} -> Enum.count(user.connections)
                    :error -> 0
                  end
    registered = case Profile.lookup(Profile, type.target) do
                   {:ok, _} -> true
                   :error -> false
                 end
    Connection.write(state, Update.reply(update, Update.UserInfo, [
              from: Lichat.server_name(),
              connections: connections,
              registered: registered ]))
    state
  end
end
