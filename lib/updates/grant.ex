use Update
defupdate(Grant, "GRANT", [:channel, :update, :target]) do
  require Logger
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        Logger.info("#{update.from} granted #{inspect(type.update)} for #{type.target} in #{type.channel}", [intent: :user])
        Channel.grant(channel, type.target, type.update)
        Connection.write(state, update)
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
