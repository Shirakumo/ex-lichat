use Update
defupdate(ShareIdentity, "SHARE-IDENTITY", [[:key, optional: true]]) do
  def handle(_type, update, state) do
    case User.create_share(state.user) do
      {:ok, key} ->
        Lichat.Connection.write(state, Update.reply(update, Update.ShareIdentity, [
                  key: key]))
      :too_many_shares ->
        Lichat.Connection.write(state, Update.fail(update, Update.IdentityAlreadyUsed,
            [text: "Too many identity shares already exist for #{update.from}"]))
    end
  end
end
