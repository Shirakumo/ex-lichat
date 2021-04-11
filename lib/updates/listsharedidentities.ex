use Update
defupdate(ListSharedIdentities, "LIST-SHARED-IDENTITIES", [[:identities, optional: true]]) do
  def handle(_type, update, state) do
    case User.get(state.user) do
      {:ok, user} ->
        identities = User.data(user).shares
        |> Enum.filter(fn key, _ -> is_binary(key) end)
        |> Enum.map(fn key, {on_behalf, _} -> [key, on_behalf] end)
        Lichat.Connection.write(state, Update.reply(update, Update.ListSharedIdentities, [
                  identities: identities ]))
      :error ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchUser))
    end
  end
end
