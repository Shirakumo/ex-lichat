use Update
defupdate(Quieted, "QUIETED", [:channel, [:target, optional: true]]) do
  require Logger
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        quieted = Channel.quieted(channel)
        Lichat.Connection.write(state, %{update | type: %{type | target: quieted}})
      :error ->
        Failure.no_such_channel(state, update)
    end
  end
end
