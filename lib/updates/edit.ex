use Update
defupdate(Edit, "EDIT", [:channel, :text, [:rich, optional: true]]) do
  def handle(_type, update, state) do
    case Channel.check_access(state, update) do
      {:error, _} -> nil
      {:ok, channel} ->
        Channel.write(channel, update)
    end
    state
  end
end
