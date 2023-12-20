use Update
defupdate(LastRead, "LAST-READ", [:channel, [:target, optional: true], [:update_id, symbol: "UPDATE-ID", optional: true]]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        case Profile.lookup(update.from) do
          :ok ->
            if type.target != nil and type.update_id != nil do
              Channel.last_read(channel, update.from, type.target, type.update_id)
              User.write(state.user, update)
            else
              {target, id} = Channel.last_read(channel, update.from)
              Lichat.Connection.write(state, %{update | type: %{type | target: target, update_id: id}})
            end
          :not_registered ->
            Lichat.Connection.write(state, Update.fail(update, Update.NoSuchProfile,
                [text: "No such profile with the name #{update.from}"]))
        end
      :error ->
        Failure.no_such_channel(state, update)
    end
    state
  end
end
