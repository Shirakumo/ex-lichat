use Update
defupdate(Disconnect, "DISCONNECT", []) do
  def handle(_type, _update, connection) do
    Lichat.Connection.close(connection)
  end
end
