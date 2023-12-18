use Update
defupdate(Backfill, "BACKFILL", [:channel, [:since, optional: true]]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          since = if is_number(type.since), do: type.since, else: 0
          case History.backlog(type.channel, since) do
            {:error, _} ->
              Lichat.Connection.write(state, Update.fail(update, Update.InvalidUpdate))
            updates ->
              Enum.each(updates, &Lichat.Connection.write(state, &1))
              Lichat.Connection.write(state, update)
          end
        else
          Lichat.Connection.write(state, Update.fail(update, Update.NotInChannel))
        end
      :error ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
