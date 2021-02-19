use Update
defupdate(Kick, "KICK", [:channel, :target]) do
  require Logger
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        cond do
          not User.in_channel?(state.user, channel) ->
            Connection.write(state, Update.fail(update, Update.NotInChannel))
          not User.in_channel?(type.target, channel) ->
            Connection.write(state, Update.fail(update, Upadet.NotInChannel))
          true ->
            Logger.info("#{update.from} kicked #{type.target} from #{type.channel}", [intent: :user])
            Channel.write(channel, update)
            Channel.write(channel, Update.reply(update, Update.Leave, [
                      channel: channel,
                      from: type.target ]))
            User.leave(state.target, channel)
        end
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
