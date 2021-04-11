use Update
defupdate(Kill, "KILL", [:target]) do
  require Logger
  def handle(type, update, state) do
    case User.get(type.target) do
      {:ok, user} ->
        Logger.info("#{update.from} killed #{type.target}", [intent: :admin])
        User.destroy(user)
        Lichat.Connection.write(state, update)
      :error ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchUser))
    end
    state
  end
end
