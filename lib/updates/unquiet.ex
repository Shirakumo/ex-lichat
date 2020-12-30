use Update
defupdate(Unquiet, "UNQUIET", [:channel, :target]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        Channel.unquiet(channel, type.target)
        Connection.write(state, update)
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
  end
end
