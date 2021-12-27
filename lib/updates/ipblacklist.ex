use Update
defupdate(IpBlacklist, "IP-BLACKLIST", [[:target, optional: true]]) do
  def handle(type, update, state) do
    blacklist = Enum.map(Blacklist.ip_list,
      fn {ip, mask} ->
        [:inet_parse.ntoa(ip), :inet_parse.ntoa(mask)]
      end)
    update = %{update | type: %{type | target: blacklist}}
    Lichat.Connection.write(state, update)
  end
end
