use Update
defupdate(Kill, "KILL", [:target]) do
  def handle(type, update, state) do
    case User.get(type.target) do
      {:ok, user} ->
        User.destroy(user)
        Connection.write(state, update)
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchUser))
    end
    state
  end
end
