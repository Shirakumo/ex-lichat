use Update
defupdate(Ban, "BAN", [:target]) do
  require Logger
  def handle(type, update, state) do
    case User.get(type.target) do
      {:ok, user} ->
        User.destroy(user)
      :error -> nil
    end
    Logger.info("#{update.from} banned #{type.target}", [intent: :admin])
    Blacklist.add_name(type.target)
    Connection.write(state, update)
  end
end
