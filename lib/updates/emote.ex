use Update
defupdate(Emote, "EMOTE", [[:content_type, symbol: "CONTENT-TYPE"], :channel, :payload, :name]) do
  require Logger
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          case Emote.save(type.channel, type.name, type.content_type, type.payload) do
            :ok ->
              Channel.write(channel, update)
            {:bad_content_type, allowed} ->
              Lichat.Connection.write(state, Update.fail(update, Update.BadContentType, [
                        allowed_content_types: allowed]))
            :too_many_emotes ->
              Lichat.Connection.write(state, Update.fail(update, Update.EmoteListFull))
            :too_large ->
              Lichat.Connection.write(state, Update.fail(update, Update.UpdateTooLong))
            {:error, reason} ->
              Logger.warning("Failed to save emote update: #{reason}")
              Lichat.Connection.write(state, Update.fail(update, Update.UpdateFailure))
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
