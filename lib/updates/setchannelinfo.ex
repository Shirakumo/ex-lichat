use Update
defupdate(SetChannelInfo, "SET-CHANNEL-INFO", [:channel, :key, :text]) do
  require Logger
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        cond do
          not Channel.valid_info?(type.key) ->
            Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannelInfo, [key: type.key]))
          not Channel.valid_info?(type.key, type.text) ->
            Lichat.Connection.write(state, Update.fail(update, Update.MalformedChannelInfo))
          true ->
            Logger.info("#{update.from} set #{inspect(type.key)} in #{type.channel}", [intent: :user])
            Channel.info(channel, type.key, type.text)
            Channel.write(channel, update)
        end
      :error ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
