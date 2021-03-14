use Update
defupdate(UnshareIdentity, "UNSHARE-IDENTITY", [[:key, optional: true]]) do
  def handle(type, update, state) do
    if type.key != nil do
      User.revoke_share(state.user, type.key)
    else
      User.revoke_all_shares(state.user)
    end
    Connection.write(state, update)
  end
end
