use Update
defupdate(Ping, "PING", []) do
  def handle(_type, update, state) do
    Lichat.Connection.write(state, Update.reply(update, Update.Pong, [
                    from: Lichat.server_name()]))
    state
  end
end
