use Update
defupdate(Blacklist, "BLACKLIST", [[:target, optional: true]]) do
  def handle(type, update, state) do
    update = %{update | type: %{type | target: Blacklist.list}}
    Lichat.Connection.write(state, update)
  end
end
