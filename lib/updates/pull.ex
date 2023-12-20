use Update
defupdate(Pull, "PULL", [:channel, :target]) do
  def handle(type, update, state) do
    case User.get(type.target) do
      {:ok, target} ->
        case Channel.check_access(state, update) do
          {:error, _} -> nil
          {:ok, channel} ->
            case User.join(target, channel) do
              :ok ->
                Channel.write(channel, Update.reply(update, Update.Join, [
                          from: type.target,
                          channel: type.channel]))
              :already_in_channel ->
                Lichat.Connection.write(state, Update.fail(update, Update.AlreadyInChannel,
                      [text: "The user #{type.target} is already in the channel #{type.channel}"]))
              :too_many_channels ->
                Lichat.Connection.write(state, Update.fail(update, Update.TooManyChannels,
                      [text: "#{type.target} is in too many channels (max #{Toolkit.config(:max_channels_per_user)})"]))
            end
        end
      :error ->
        Failure.no_such_user(state, update)
    end
    state
  end
end
