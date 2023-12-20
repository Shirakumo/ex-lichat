use Update
defupdate(React, "REACT", [:channel, :target, [:update_id, symbol: "UPDATE-ID"], :emote]) do
  def handle(type, update, state) do
    case Channel.check_access(state, update) do
      {:error, _} -> nil
      {:ok, channel} ->
        if not Toolkit.valid_emote?(type.channel, type.emote) do
          Lichat.Connection.write(state, Update.fail(update, Update.UpdateFailure,
              [text: "The emote is not valid: #{type.emote}"]))
        else
          Channel.write(channel, update)
        end
    end
    state
  end
end
