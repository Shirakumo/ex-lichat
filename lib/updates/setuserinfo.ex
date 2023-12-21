use Update
defupdate(SetUserInfo, "SET-USER-INFO", [:key, :text]) do
  require Logger
  def handle(type, update, state) do
    case Profile.lookup(update.from) do
      :ok ->
        cond do
          not Profile.valid_info?(type.key) ->
            Lichat.Connection.write(state, Update.fail(update, Update.NoSuchUserInfo,
                  [key: type.key, text: "The user info key #{type.key} is not valid"]))
          not Profile.valid_info?(type.key, type.text) ->
            Lichat.Connection.write(state, Update.fail(update, Update.MalformedUserInfo,
                  [text: "The user info value is malformed for the key #{type.key}"]))
          true ->
            Logger.info("#{update.from} set #{inspect(type.key)} for themselves.", [intent: :user])
            try do
              Profile.info(update.from, type.key, type.text)
              Lichat.Connection.write(state, update)
            rescue
              e in RuntimeError ->
                Logger.error("Failed to set user key #{type.key}: #{inspect(e)}")
                Lichat.Connection.write(state, Update.fail(update, Update.MalformedChannelInfo,
                      [text: "The channel info value is malformed for the key #{type.key}"]))
            end
        end
      :not_registered ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchProfile,
            [text: "No such profile with name #{update.from}"]))
    end
    state
  end
end
