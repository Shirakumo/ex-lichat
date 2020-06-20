defmodule Update.Connect do
  defstruct password: nil, version: nil, extensions: []
end

defimpl Update.Serialize, for: Update.Connect do
  def type_symbol(_), do: %Symbol{name: "CONNECT", package: :lichat}
  def to_list(type) do
    [ :password, type.password,
      :version, type.version,
      :extensions, type.extensions ]
  end
  def from_list(_, args) do
    Update.from_list(%Update{},
      [ :type, %Update.Connect{
          password: Toolkit.getf(args, :password),
          version: Toolkit.getf!(args, :version),
          extensions: Toolkit.getf(args, :extensions)}
        | args ])
  end
end

defimpl Update.Execute, for: Update.Connect do
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
