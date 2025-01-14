use Update
defupdate(Unban, "UNBAN", [:target]) do
  require Logger
  def handle(type, update, state) do
    Logger.info("#{update.from} unbanned #{type.target}", [intent: :admin])
    IpLog.record(state, Update.Unban, type.target)
    Blacklist.delete_name(type.target)
    Lichat.Connection.write(state, update)
  end
end
