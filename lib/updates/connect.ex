use Update
defupdate(Connect, "CONNECT", [[:password, required: false], :version, [:extensions, required: false]]) do
  require Logger
  def handle(type, update, connection) do
    case connection.state do
      nil ->
        update = if update.from in [nil, false, "", []] do
            %{update | from: User.random_name()}
          else update end
        cond do
          not Toolkit.valid_name?(update.from) ->
            Lichat.Connection.write(connection, Update.fail(update, Update.BadName))
            Lichat.Connection.close(connection)
          not Lichat.compatible?(type.version) ->
            Lichat.Connection.write(connection, Update.fail(update, Update.IncompatibleVersion, [
                      compatible_versions: Lichat.compatible_versions()
                    ]))
            Lichat.Connection.close(connection)
          Blacklist.has?(update.from) ->
            Logger.info("Connection from #{update.from} at #{Toolkit.ip(connection.ip)} denied: name on blacklist")
            Lichat.Connection.write(connection, Update.fail(update, Update.TooManyConnections))
            Lichat.Connection.close(connection)
          true ->
            case Profile.check(update.from, type.password) do
              :not_registered ->
                cond do
                  is_binary(type.password) ->
                    Lichat.Connection.write(connection, Update.fail(update, Update.NoSuchProfile))
                    Lichat.Connection.close(connection)
                  User.get(update.from) != :error ->
                    Lichat.Connection.write(connection, Update.fail(update, Update.UsernameTaken))
                    Lichat.Connection.close(connection)
                  true ->
                    Lichat.Connection.establish(connection, update)
                end
              :bad_password ->
                Logger.info("Connection from #{update.from} at #{Toolkit.ip(connection.ip)} denied: invalid password")
                Lichat.Connection.write(connection, Update.fail(update, Update.InvalidPassword))
                Lichat.Connection.close(connection)
              :ok ->
                case User.get(update.from) do
                  :error ->
                    Lichat.Connection.establish(connection, update)
                  {:ok, user} ->
                    if Enum.count(User.connections(user)) < Toolkit.config(:max_connections_per_user, 20) do
                      Lichat.Connection.establish(connection, update)
                    else
                      Lichat.Connection.write(connection, Update.fail(update, Update.TooManyConnections))
                      Lichat.Connection.close(connection)
                    end
                end
            end
        end
      _ ->
        Lichat.Connection.write(connection, Update.fail(update, Update.AlreadyConnected))
        connection
    end
  end
end
