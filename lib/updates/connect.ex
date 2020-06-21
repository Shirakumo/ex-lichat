use Update
defupdate(Connect, "CONNECT", [:password, :version, :extensions]) do
  def handle(type, update, connection) do
    case connection.state do
      nil ->
        profile = %Profile{name: update.from, password: type.password}
        case Profile.check(Profile, profile) do
          :not_registered ->
            if type.password == nil do
              Connection.establish(connection, update)
            else
              # Connection.write(connection, %NoSuchProfile)
              Connection.close(connection)
            end
          :bad_password ->
            # Connection.write(connection, %InvalidPassword)
            Connection.close(connection)
          :ok ->
            Connection.establish(connection, update)
        end
      _ ->
        # Connection.write(connection, %AlreadyConnected)
        connection
    end
  end
end
