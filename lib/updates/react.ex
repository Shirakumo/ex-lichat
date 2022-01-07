use Update
defupdate(React, "REACT", [:channel, :target, [:update_id, symbol: "UPDATE-ID"], :emote]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        cond do
          not User.in_channel?(state.user, channel) ->
            Lichat.Connection.write(state, Update.fail(update, Update.NotInChannel))
          not Toolkit.valid_emote?(type.channel, type.emote) ->
            Lichat.Connection.write(state, Update.fail(update, Update.UpdateFailure))
          true ->
            Channel.write(channel, update)
        end
      :error ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
