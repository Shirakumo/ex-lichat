use Update
defupdate(Kill, "KILL", [:target]) do
  require Logger
  def handle(type, update, state) do
    case User.get(type.target) do
      {:ok, user} ->
        Logger.info("#{update.from} killed #{type.target}", [intent: :admin])
        History.ip_log(state, Update.Kill, type.target)
        User.destroy(user)
        Lichat.Connection.write(state, update)
      :error ->
        Failure.no_such_user(state, update)
    end
    state
  end
end
