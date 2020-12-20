use Update
defupdate(Channels, "CHANNELS", []) do
  def handle(_type, update, state) do
    ## TODO: Check permissions on each and filter.
    Connection.write(state, Update.reply(update, Update.Channels, [channels: Channel.list(Channel)]))
    state
  end
end
