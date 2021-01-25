use Update
defupdate(ServerInfo, "SERVER-INFO", [:target]) do
  def handle(type, update, state) do
    case User.get(type.target) do
      {:ok, user} ->
        attributes = [
          [%Symbol{package: "lichat", name: "channels"},
           Enum.map(User.channels(user), fn {_, {_, name}} -> name end)]
        ]
          
        connections = User.connections(user)
        |> Enum.map(fn {connection, _} ->
          data = Connection.data(connection)
          [[%Symbol{package: "lichat", name: "connected-on"}, data.started_on],
           [%Symbol{package: "shirakumo", name: "ip"}, :inet_parse.ntoa(data.ip)],
           [%Symbol{package: "shirakumo", name: "ssl"}, data.ssl]]
        end)
        Connection.write(state, Update.make(Update.ServerInfo, [
                  id: update.id, attributes: attributes, connections: connections]))
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchUser))
    end
    state
  end
end