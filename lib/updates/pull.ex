use Update
defupdate(Pull, "PULL", [:channel, :target]) do
  def handle(type, update, state) do
    case User.get(type.target) do
      {:ok, target} ->
        case Channel.get(type.channel) do
          {:ok, channel} ->
            if not User.in_channel?(state.user, channel) do
              Lichat.Connection.write(state, Update.fail(update, Update.NotInChannel))
            else
              case User.join(target, channel) do
                :ok ->
                  Channel.write(channel, Update.reply(update, Update.Join, [
                            from: type.target,
                            channel: type.channel]))
                :already_in_channel ->
                  Lichat.Connection.write(state, Update.fail(update, Update.AlreadyInChannel))
                :too_many_channels ->
                  Lichat.Connection.write(state, Update.fail(update, Update.TooManyChannels))
              end
            end
          :error ->
            Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel))
        end
      :error ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchUser))
    end
    state
  end
end
