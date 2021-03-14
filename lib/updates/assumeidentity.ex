use Update
defupdate(AssumeIdentity, "ASSUME-IDENTITY", [:target, :key]) do
  def handle(type, update, state) do
    if Map.has_key?(state.identities, type.target) do
      Connection.write(state, Update.fail(update, Update.IdentityAlreadyUsed))
    else
      case User.assume(type.target, type.key) do
        {:ok, user} ->
          identities = state.identities
          |> Map.put(type.target, user)
          |> Map.put(user, {type.target, Process.monitor(user)})
          state = %{state | identities: identities}
          Connection.write(state, update)
        :key_used ->
          Connection.write(state, Update.fail(update, Update.IdentityAlreadyUsed))
        :no_such_key ->
          Connection.write(state, Update.fail(update, Update.IdentityAlreadyUsed))
        :no_such_user ->
          Connection.write(state, Update.fail(update, Update.NoSuchUser))
      end
    end
  end
end
