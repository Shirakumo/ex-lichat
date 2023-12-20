use Update
defupdate(Message, "MESSAGE", [:channel, :text, [:bridge, optional: true], [:link, optional: true], [:reply_to, optional: true, symbol: "REPLY-TO"], [:rich, optional: true]]) do
  def handle(type, update, state) do
    case Channel.check_access(state, update) do
      {:error, _} -> nil
      {:ok, channel} ->
        if is_binary(type.bridge) do
          Update.Bridge.bridge(type, update, state, channel)
        else
          Channel.write(channel, %{update | type: Map.delete(type, :bridge)})
        end
    end
    state
  end
end
