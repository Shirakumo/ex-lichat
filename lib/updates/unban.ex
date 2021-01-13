use Update
defupdate(Unban, "UNBAN", [:target]) do
  def handle(type, update, state) do
    Blacklist.delete_name(type.target)
    Connection.write(state, update)
  end
end
