use Update
defupdate(Register, "REGISTER", [:password]) do
  def handle(type, update, state) do
    case Profile.register(Profile, %Profile{name: type.from, password: update.password}) do
      :ok ->
        Connection.write(state, update)
      {:error, reason} ->
        Connection.write(state, Update.fail(update, Update.RegistrationRejected, [
                text: reason )))
    end
    state
  end
end
