use Update
defupdate(Emote, "EMOTE", [[:content_type, symbol: "CONTENT-TYPE"], :channel, :payload, :name]) do
  require Logger
  def handle(type, update, state) do
    case Channel.check_access(state, update) do
      {:error, _} -> nil
      {:ok, channel} ->
        case Emote.save(type.channel, type.name, type.content_type, type.payload) do
          :ok ->
            Channel.write(channel, update)
          {:bad_content_type, allowed} ->
            Lichat.Connection.write(state, Update.fail(update, Update.BadContentType,
                  [allowed_content_types: allowed, text: "The content-type #{type.content_type} is not allowed. Allowed are: #{Enum.join(allowed, ", ")}"]))
          :too_many_emotes ->
            Lichat.Connection.write(state, Update.fail(update, Update.EmoteListFull,
                  [text: "There are too many emotes on this channel already. (max: #{Toolkit.config(:max_emotes_per_channel)})"]))
          :too_large ->
            Lichat.Connection.write(state, Update.fail(update, Update.UpdateTooLong,
                  [text: "The emote is too large. (max: #{Toolkit.config(:max_emote_size)})"]))
          {:error, reason} ->
            Logger.warning("Failed to save emote update: #{reason}")
            Lichat.Connection.write(state, Update.fail(update, Update.UpdateFailure,
                  [text: "Internal server failure saving emote."]))
        end
    end
    state
  end
end
