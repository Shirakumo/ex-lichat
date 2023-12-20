use Update
defupdate(Quiet, "QUIET", [:channel, :target]) do
  require Logger
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        Logger.info("#{update.from} quieted #{type.target} in #{type.channel}", [intent: :user])
        Channel.quiet(channel, type.target)
        Lichat.Connection.write(state, update)
      :error ->
        Failure.no_such_channel(state, update)
    end
  end
end
