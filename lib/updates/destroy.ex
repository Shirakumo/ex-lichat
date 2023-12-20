use Update
defupdate(Destroy, "DESTROY", [:channel]) do
  require Logger
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        Logger.info("#{update.from} destroyed #{type.channel}", [intent: :admin])
        Channel.destroy(channel)
        Lichat.Connection.write(state, update)
      :error ->
        Failure.no_such_channel(state, update)
    end
    state
  end
end
