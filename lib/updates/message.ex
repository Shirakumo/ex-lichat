use Update
defupdate(Message, "MESSAGE", [:channel, :text, [:bridge, optional: true]]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        cond do
          not User.in_channel?(state.user, channel) ->
            Lichat.Connection.write(state, Update.fail(update, Update.NotInChannel))
          is_binary(type.bridge) ->
            Update.Bridge.bridge(type, update, state, channel)
          true->
            Channel.write(channel, %{update | type: Map.delete(type, :bridge)})
        end
      :error ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
