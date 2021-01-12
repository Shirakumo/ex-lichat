use Update
defupdate(Destroy, "DESTROY", [:channel]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        Channel.destroy(channel)
        Connection.write(state, update)
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
