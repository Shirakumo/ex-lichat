use Update
require Logger
defupdate(Backfill, "BACKFILL", [:channel, [:since, optional: true]]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          since = if is_number(type.since), do: type.since, else: 0
          case History.backlog(type.channel, since) do
            {:error, :not_connected} ->
              Lichat.Connection.write(state, Update.fail(update, Update.UpdateFailure, [text: "Backfill unavailable"]))
            {:error, error} ->
              Logger.error("Failed to fetch backfill for #{type.channel}: #{inspect(error)}")
              Lichat.Connection.write(state, Update.fail(update, Update.UpdateFailure, [text: "Internal error"]))
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
