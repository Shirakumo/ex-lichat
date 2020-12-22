use Update
defupdate(Edit, "EDIT", [:channel, :text]) do
  def handle(type, update, state) do
    case Channel.get(Channel, type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          Channel.write(channel, update)
        else
          Connection.write(state, Update.fail(update, Update.NotInChannel))
        end
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
