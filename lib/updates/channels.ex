use Update
defupdate(Channels, "CHANNELS", []) do
  def handle(_type, update, state) do
    channels = Enum.filter(Channel.list(Channel), &Channel.permitted(&1, update))
    Connection.write(state, Update.reply(update, Update.Channels, [channels: channels]))
    state
  end
end
