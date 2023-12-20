use Update
defupdate(Kick, "KICK", [:channel, :target]) do
  require Logger
  def handle(type, update, state) do
    case Channel.check_access(state, update) do
      {:error, _} -> nil
      {:ok, channel} ->
        if not User.in_channel?(type.target, channel) do
          Lichat.Connection.write(state, Update.fail(update, Upadet.NotInChannel))
        else
          Logger.info("#{update.from} kicked #{type.target} from #{type.channel}", [intent: :user])
          Channel.write(channel, update)
          Channel.write(channel, Update.reply(update, Update.Leave, [
                    channel: channel,
                    from: type.target ]))
          User.leave(state.target, channel)
        end
    end
    state
  end
end
