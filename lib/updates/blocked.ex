use Update
defupdate(Blocked, "BLOCKED", [[:target, optional: true]]) do
  def handle(type, update, state) do
    case Profile.blocked(update.from) do
      :not_registered ->
        Lichat.Connection.write(state, Update.fail(Update.NoSuchProfile,
              [text: "Your username #{update.from} is not registered."]))
      map ->
        update = %{update | type: %{type | target: MapSet.to_list(map)}}
        Lichat.Connection.write(state, update)
    end
  end
end
