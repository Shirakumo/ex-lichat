use Update
defupdate(ShareIdentity, "SHARE-IDENTITY", [[:key, optional: true]]) do
  def handle(_type, update, state) do
    case User.create_share(state.user) do
      {:ok, key} ->
        Connection.write(state, Update.reply(update, Update.ShareIdentity, [
                  key: key]))
      :too_many_shares ->
        Connection.write(state, Update.fail(update, Update.IdentityAlreadyUsed))
    end
  end
end
