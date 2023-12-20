use Update
defupdate(Typing, "TYPING", [:channel, [:bridge, optional: true]]) do
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
