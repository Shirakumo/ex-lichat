use Update
defupdate(Capabilities, "CAPABILITIES", [:channel, [:permitted, required: false]]) do
  def handle(type, update, state) do
    case Channel.check_access(state, update) do
      {:error, _} -> nil
      {:ok, channel} ->
        user = String.downcase(update.from)
        permitted = Channel.data(channel).permissions
        |> Enum.filter(fn {type, map} ->
          Update.is_update?(type)
          and Map.get(map, user, Map.get(map, :default, false))
        end)
        |> Enum.map(fn {type, _map} ->
          type.type_symbol()
        end)
        Lichat.Connection.write(state, %{update | type: %{type | permitted: permitted}})
    end
    state
  end
end
