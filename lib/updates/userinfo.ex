use Update
defupdate(UserInfo, "USER-INFO", [:target]) do
  def handle(type, update, state) do
    connections = case User.get(type.target) do
                    {:ok, user} -> Enum.count(user.connections)
                    :error -> 0
                  end
    registered = case Profile.lookup(type.target) do
                   {:ok, _} -> true
                   :not_registered -> false
                 end
    Connection.write(state, Update.reply(update, Update.UserInfo, [
              from: Lichat.server_name(),
              connections: connections,
              registered: registered ]))
    state
  end
end
