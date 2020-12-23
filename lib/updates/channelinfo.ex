use Update
defupdate(ChannelInfo, "CHANNEL-INFO", [:channel, :keys]) do
  def handle(type, update, state) do
    case Channel.get(Channel, type.channel) do
      {:ok, channel} ->
        map = if update.keys == true do
            Channel.info(channel)
          else
            keys = Enum.filter(update.keys, fn k ->
              if Channel.valid_info(k) do
                true
              else
                Connection.write(state, Update.fail(update, Update.NoSuchChannelInfo, [key: k]))
                false
              end
            end)
            Enum.filter(Channel.info(channel), fn {k, _} -> Enum.member?(keys, k) end)
          end
        Enum.each(map, fn {k, v} ->
          Connection.write(state, Update.reply(update, Update.SetChannelInfo, [
                    key: k,
                    text: v
                  ]))
        end)
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
