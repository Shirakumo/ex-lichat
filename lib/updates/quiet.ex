use Update
defupdate(Quiet, "QUIET", [:channel, :target]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        Channel.quiet(channel, type.target)
        Connection.write(state, update)
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
  end
end
