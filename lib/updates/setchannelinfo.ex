use Update
defupdate(SetChannelInfo, "SET-CHANNEL-INFO", [:channel, :key, :text]) do
  def handle(type, update, state) do
    case Channel.get(Channel, type.channel) do
      {:ok, channel} ->
        cond do
          not Channel.valid_info(update.key) ->
            Connection.write(state, Update.fail(update, Update.NoSuchChannelInfo, [key: update.key]))
          not Channel.valid_info(update.key, update.value) ->
            Connection.write(state, Update.fail(update, Update.MalformedChannelInfo))
          true ->
            Channel.info(channel, update.key, update.value)
            Channel.write(channel, update)
        end
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
