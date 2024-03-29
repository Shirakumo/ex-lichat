use Update
defupdate(ChannelInfo, "CHANNEL-INFO", [:channel, :keys]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        map = if type.keys == true do
            Channel.info(channel)
          else
            keys = Enum.filter(type.keys, fn k ->
              if Channel.valid_info?(k) do
                true
              else
                Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannelInfo,
                      [key: k, text: "The channel info key #{k} is unset on #{type.channel}"]))
                false
              end
            end)
            Enum.filter(Channel.info(channel), fn {k, _} -> Enum.member?(keys, k) end)
          end
        Enum.each(map, fn {k, v} ->
          Lichat.Connection.write(state, Update.reply(update, Update.SetChannelInfo, [
                    from: Lichat.server_name(),
                    channel: type.channel,
                    key: k,
                    text: v
                  ]))
        end)
      :error ->
        Failure.no_such_channel(state, update)
    end
    state
  end
end
