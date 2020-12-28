use Update
defupdate(Connect, "CONNECT", [[:password, required: false], :version, [:extensions, required: false]]) do
  def handle(type, update, connection) do
    case connection.state do
      nil ->
        update = if update.from in [nil, false, ""] do
            %{update | from: User.random_name(User)}
          else update end
        cond do
          not Toolkit.valid_name?(update.from) ->
            Connection.write(connection, Update.fail(update, Update.BadName))
            Connection.close(connection)
          not Lichat.compatible?(type.version) ->
            Connection.write(connection, Update.fail(update, Update.IncompatibleVersion, [
                      compatible_versions: Lichat.compatible_versions()
                    ]))
            Connection.close(connection)
          true ->
            case Profile.check(Profile, update.from, type.password) do
              :not_registered ->
                cond do
                  is_binary(type.password) ->
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
        end
      _ ->
        Connection.write(connection, Update.fail(update, Update.AlreadyConnected))
        connection
    end
  end
end
