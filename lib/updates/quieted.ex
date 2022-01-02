use Update
defupdate(Quieted, "QUIETED", [:channel, [:target, optional: true]]) do
  require Logger
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        quieted = Channel.quieted(channel)
        Lichat.Connection.write(state, %{update | type: %{type | target: quieted}})
      :error ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
  end
end
