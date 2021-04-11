use Update
defupdate(IpUnban, "IP-UNBAN", [:ip, :mask]) do
  require Logger
  def handle(type, update, state) do
    Logger.info("#{update.from} unbanned #{type.ip}/#{type.mask}", [intent: :admin])
    Blacklist.delete_ip(type.ip, type.mask)
    Lichat.Connection.write(state, update)
  end
end
