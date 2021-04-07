use Update
defupdate(Pull, "PULL", [:channel, :target]) do
  def handle(type, update, state) do
    case User.get(type.target) do
      {:ok, target} ->
        case Channel.get(type.channel) do
          {:ok, channel} ->
            cond do
              not User.in_channel?(state.user, channel) ->
                Connection.write(state, Update.fail(update, Update.NotInChannel))
              User.in_channel?(target, channel) ->
                Connection.write(state, Update.fail(update, Update.AlreadyInChannel))
              true ->
                User.join(target, channel)
                Channel.write(channel, Update.reply(update, Update.Join, [
                          from: type.target,
                          channel: type.channel]))
            end
          :error ->
            Connection.write(state, Update.fail(update, Update.NoSuchChannel))
        end
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchUser))
    end
    state
  end
end
