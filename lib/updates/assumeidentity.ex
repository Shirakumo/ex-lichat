use Update
defupdate(AssumeIdentity, "ASSUME-IDENTITY", [:target, :key]) do
  def handle(type, update, state) do
    if Map.has_key?(state.identities, type.target) do
      Lichat.Connection.write(state, Update.fail(update, Update.IdentityAlreadyUsed))
    else
      case User.assume(type.target, type.key) do
        {:ok, user} ->
          IpLog.record(state, Update.AssumeIdentity, type.target)
          identities = state.identities
          |> Map.put(type.target, user)
          |> Map.put(user, {type.target, Process.monitor(user)})
          state = %{state | identities: identities}
          Lichat.Connection.write(state, update)
        :key_used ->
          Lichat.Connection.write(state, Update.fail(update, Update.IdentityAlreadyUsed))
        :no_such_key ->
          Lichat.Connection.write(state, Update.fail(update, Update.IdentityAlreadyUsed))
        :no_such_user ->
          Failure.no_such_user(state, update)
      end
    end
  end
end
