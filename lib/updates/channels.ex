use Update
defupdate(Channels, "CHANNELS", [[:channels, required: false], [:channel, required: false]]) do
  require Logger 
  def handle(type, update, state) do
    channels = Channel.list(type.channel, :pids)
    |> Enum.filter(fn {_name, pid} -> Channel.permitted?(pid, update) end)
    |> Enum.map(fn {name, _} -> name end)
    Lichat.Connection.write(state, Update.reply(update, Update.Channels, [
              from: Lichat.server_name(),
              channels: channels ]))
    state
  end
end
