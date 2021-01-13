use Update
defupdate(IpBan, "IP-BAN", [:ip, :mask]) do
  def handle(type, update, state) do
    Blacklist.add_ip(type.ip, type.mask)
    # FIXME: Kill matching connections now
    Connection.write(state, update)
  end
end
