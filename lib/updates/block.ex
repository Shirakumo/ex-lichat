use Update
defupdate(Block, "BLOCK", [:target]) do
  def handle(type, update, state) do
    case Profile.lookup(update.from) do
      :ok ->
        User.block(update.from, type.target)
        Profile.block(update.from, type.target)
        Connection.write(state, update)
      true ->
        Connection.write(state, Update.fail(Update.NoSuchProfile))
    end
  end
end
