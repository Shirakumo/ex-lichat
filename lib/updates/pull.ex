use Update
defupdate(Pull, "PULL", [:channel, :target]) do
  def handle(type, update, state) do
    case Channel.get(Channel, type.channel) do
      {:ok, channel} ->
        cond do
          not User.in_channel?(state.user, channel) ->
            Connection.write(state, Update.fail(update, Update.NotInChannel))
          User.in_channel?(state.target, channel) ->
            Connection.write(state, Update.fail(update, Update.AlreadyInChannel))
          true ->
            User.join(state.target, channel)
            Channel.write(channel, Update.reply(update, Update.Join, [
                      channel: type.channel]))
        end
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
