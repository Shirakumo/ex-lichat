use Update
defupdate(Connect, "CONNECT", [[:password, required: false], :version, [:extensions, required: false]]) do
  def handle(type, update, connection) do
    case connection.state do
      nil ->
        if Lichat.compatible?(update.version) do
          profile = %Profile{name: update.from, password: type.password}
          case Profile.check(Profile, profile) do
            :not_registered ->
              cond do
                type.password != nil ->
                  Connection.write(connection, Update.fail(update, Update.NoSuchProfile))
                  Connection.close(connection)
                User.get(User, update.from) != :error ->
                  Connection.write(connection, Update.fail(update, Update.UsernameTaken))
                  Connection.close(connection)
                true ->
                  Connection.establish(connection, update)
              end
            :bad_password ->
              Connection.write(connection, Update.fail(update, Update.InvalidPassword))
              Connection.close(connection)
            :ok ->
              case User.get(User, update.from) do
                :error ->
                  Connection.establish(connection, update)
                {:ok, user} ->
                  if Enum.count(User.connections(user)) < Toolkit.config(:max_connections_per_user, 20) do
                    Connection.establish(connection, update)
                  else
                    Connection.write(connection, Update.fail(update, Update.TooManyConnections))
                    Connection.close(connection)
                  end
              end
          end
        else
          Connection.write(connection, Update.fail(update, Update.IncompatibleVersion, [
                    compatible_versions: Lichat.compatible_versions()
                  ]))
          Connection.close(connection)
        end
      _ ->
        Connection.write(connection, Update.fail(update, Update.AlreadyConnected))
        connection
    end
  end
end
