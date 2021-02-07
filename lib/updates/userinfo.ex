use Update
defupdate(UserInfo, "USER-INFO", [:target, [:info, required: false]]) do
  def handle(type, update, state) do
    connections = case User.get(type.target) do
                    {:ok, user} -> Enum.count(User.connections(user))
                    :error -> 0
                  end
    registered = case Profile.lookup(type.target) do
                   :ok -> true
                   :not_registered -> false
                 end
    info = case Profile.info(type.target) do
             :not_registered -> []
             info -> Enum.map(info, fn {key, text} -> [key, text] end)
           end
    Connection.write(state, Update.reply(update, Update.UserInfo, [
              from: Lichat.server_name(),
              connections: connections,
              registered: registered,
              info: info ]))
    state
  end
end
