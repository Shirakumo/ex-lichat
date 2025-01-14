use Update
defupdate(Block, "BLOCK", [:target]) do
  def handle(type, update, state) do
    case Profile.lookup(update.from) do
      :ok ->
        IpLog.record(state, Update.Block, type.target)
        User.block(update.from, type.target)
        Profile.block(update.from, type.target)
        Lichat.Connection.write(state, update)
      true ->
        Lichat.Connection.write(state, Update.fail(Update.NoSuchProfile,
              [text: "Your username #{update.from} is not registered."]))
    end
  end
end
