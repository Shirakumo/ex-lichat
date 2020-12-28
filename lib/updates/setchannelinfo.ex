use Update
defupdate(SetChannelInfo, "SET-CHANNEL-INFO", [:channel, :key, :text]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        cond do
          not Channel.valid_info(type.key) ->
            Connection.write(state, Update.fail(update, Update.NoSuchChannelInfo, [key: type.key]))
          not Channel.valid_info(type.key, type.value) ->
            Connection.write(state, Update.fail(update, Update.MalformedChannelInfo))
          true ->
            Channel.info(channel, type.key, type.value)
            Channel.write(channel, update)
        end
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
