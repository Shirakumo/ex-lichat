use Update
defupdate(IpUnban, "IP-UNBAN", [:ip, :mask]) do
  def handle(type, update, state) do
    Blacklist.delete_ip(type.ip, type.mask)
    Connection.write(state, update)
  end
end
