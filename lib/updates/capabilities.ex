use Update
defupdate(Capabilities, "CAPABILITIES", [:channel, [:permitted, required: false]]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          permitted = Channel.data(channel).permissions
          |> Enum.filter(fn {_type, map} ->
            Map.get(map, update.from, Map.get(map, :default, false))
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
