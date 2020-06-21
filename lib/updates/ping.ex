use Update
defupdate(Ping, "PING", []) do
  def handle(_type, update, state) do
    Connection.write(state, Update.reply(update, Update.Pong, []))
    state
  end
end
