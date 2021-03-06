use Update
defupdate(Unblock, "UNBLOCK", [:target]) do
  def handle(type, update, state) do
    case Profile.lookup(update.from) do
      :ok ->
        User.unblock(update.from, type.target)
        Profile.unblock(update.from, type.target)
        Lichat.Connection.write(state, update)
      true ->
        Lichat.Connection.write(state, Update.fail(Update.NoSuchProfile))
    end
  end
end
