use Update
defupdate(ServerInfo, "SERVER-INFO", [:target, [:attributes, optional: true], [:connections, optional: true]]) do
  require Logger
  def handle(type, update, state) do
    case User.get(type.target) do
      {:ok, user} ->
        attributes = [
          [%Symbol{package: "lichat", name: "channels"},
           Enum.map(User.channels(user), fn {_, {_, name}} -> name end)]
        ]
          
        connections = User.connections(user)
        |> Enum.map(fn {connection, _} ->
          data = Lichat.Connection.data(state, connection)
          [[%Symbol{package: "lichat", name: "connected-on"}, data.started_on],
           [%Symbol{package: "shirakumo", name: "ip"}, Toolkit.ip(data.ip)],
           [%Symbol{package: "shirakumo", name: "ssl"}, data.ssl]]
        end)
        Lichat.Connection.write(state, Update.make(Update.ServerInfo, [
                  id: update.id, target: type.target, attributes: attributes, connections: connections]))
      :error ->
        Failure.no_such_user(state, update)
    end
    state
  end
end
