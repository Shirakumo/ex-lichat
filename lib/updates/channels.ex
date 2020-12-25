use Update
defupdate(Channels, "CHANNELS", [[:channels, required: false]]) do
  require Logger 
  def handle(_type, update, state) do
    channels = Enum.filter(Channel.list(Channel), &Channel.permitted?(&1, update))
    Logger.info("test #{inspect(channels)}")
    Connection.write(state, Update.reply(update, Update.Channels, [
              from: Lichat.server_name(),
              channels: channels ]))
    state
  end
end
