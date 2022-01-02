use Update
defupdate(Capabilities, "CAPABILITIES", [:channel, [:permitted, required: false]]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          user = String.downcase(update.from)
          permitted = Channel.data(channel).permissions
          |> Enum.filter(fn {type, map} ->
            Update.is_update?(type)
            and Map.get(map, user, Map.get(map, :default, false))
          end)
          |> Enum.map(fn {type, _map} ->
            type.type_symbol
          end)
          Lichat.Connection.write(state, %{update | type: %{type | permitted: permitted}})
        else
          Lichat.Connection.write(state, Update.fail(update, Update.NotInChannel))
        end
      :error ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
