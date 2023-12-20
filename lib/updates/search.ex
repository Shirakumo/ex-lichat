use Update
require Logger
defupdate(Search, "SEARCH", [:channel, [:results, optional: true], [:offset, optional: true], [:query, optional: true]]) do
  def handle(type, update, state) do
    case Channel.check_access(state, update) do
      {:error, _} -> nil
      {:ok, _} ->
        offset = if type.offset == nil, do: 0, else: type.offset
        case History.search(type.channel, type.query, offset) do
          {:error, :not_connected} ->
            Lichat.Connection.write(state, Update.fail(update, Update.UpdateFailure,
                  [text: "Search unavailable"]))
          {:error, error} ->
            Logger.error("Failed to search #{type.channel} with #{type.query}: #{inspect(error)}")
            Lichat.Connection.write(state, Update.fail(update, Update.UpdateFailure,
                  [text: "Internal error"]))
          updates ->
            Lichat.Connection.write(state, %{update | type: %{type | results: Enum.map(updates, &Update.to_list/1)}})
        end
    end
    state
  end
end
