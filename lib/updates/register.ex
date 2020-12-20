use Update
defupdate(Register, "REGISTER", [:password]) do
  def handle(_type, update, state) do
    Connection.write(state, Update.fail(update, Update.RegistrationRejected))
    state
  end
end
