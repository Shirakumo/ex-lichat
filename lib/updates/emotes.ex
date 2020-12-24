use Update
defupdate(Emotes, "EMOTES", [:names]) do
  def handle(type, update, state) do
    Enum.each(Emote.list(Emote), fn emote -> 
      if not Enum.member?(type.names, emote.name) do
        Connection.write(state, Update.reply(update, Update.Emote, [
                  name: emote.name,
                  content_type: emote.type,
                  payload: emote.payload ]))
      end
    end)
    state
  end
end
