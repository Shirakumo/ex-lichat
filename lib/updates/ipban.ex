use Update
defupdate(IpBan, "IP-BAN", [:ip, :mask]) do
  require Logger
  def handle(type, update, state) do
    Logger.info("#{update.from} banned #{type.ip}/#{type.mask}", [intent: :admin])
    History.ip_log(state, Update.IpBan, type.ip)
    Blacklist.add_ip(type.ip, type.mask)
    # FIXME: Kill matching connections now
    Lichat.Connection.write(state, update)
  end
end
