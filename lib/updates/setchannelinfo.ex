use Update
defupdate(SetChannelInfo, "SET-CHANNEL-INFO", [:channel, :key, :text]) do
  require Logger
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        cond do
          not Channel.valid_info?(type.key) ->
            Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannelInfo,
                  [key: type.key, text: "The channel info key #{type.key} is not valid"]))
          not Channel.valid_info?(type.key, type.text) ->
            Lichat.Connection.write(state, Update.fail(update, Update.MalformedChannelInfo,
                  [text: "The channel info value is malformed for the key #{type.key}"]))
          true ->
            Logger.info("#{update.from} set #{inspect(type.key)} in #{type.channel}", [intent: :user])
            try do
              IpLog.record(state, Update.SetChannelInfo, type.channel)
              Channel.info(channel, type.key, type.text)
              Channel.write(channel, update)
            rescue
              e in RuntimeError ->
                Logger.error("Failed to set channel key #{type.key}: #{inspect(e)}")
                Lichat.Connection.write(state, Update.fail(update, Update.MalformedChannelInfo,
                      [text: "The channel info value is malformed for the key #{type.key}"]))
            end
        end
      :error ->
        Failure.no_such_channel(state, update)
    end
    state
  end
end
