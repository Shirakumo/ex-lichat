use Update
defupdate(Edit, "EDIT", [:channel, :text, [:rich, optional: true]]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          Channel.write(channel, update)
        else
          Lichat.Connection.write(state, Update.fail(update, Update.NotInChannel))
        end
      :error ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
