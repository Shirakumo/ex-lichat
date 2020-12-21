use Update
defupdate(Connect, "CONNECT", [[:password, required: false], :version, [:extensions, required: false]]) do
  def handle(type, update, connection) do
    case connection.state do
      nil ->
        if Version.compatible?(update.version) do
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
              Connection.establish(connection, update)
          end
          _ ->
            Connection.write(connection, Update.fail(update, Update.AlreadyConnected))
            connection
        else
          Connection.write(connection, Update.fail(update, Update.IncompatibleVersion, [
                    compatible_versions: Version.compatible_versions()
                  ]))
          Connection.close(connection)
        end
    end
  end
end
