use Update
defupdate(Ban, "BAN", [:target]) do
  def handle(type, update, state) do
    case User.get(type.target) do
      {:ok, user} ->
        User.destroy(user)
      :error -> nil
    end
    Blacklist.add_name(type.target)
    Connection.write(state, update)
  end
end
