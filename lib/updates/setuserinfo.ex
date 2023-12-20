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
            Profile.info(update.from, type.key, type.text)
            Lichat.Connection.write(state, update)
        end
      :not_registered ->
        Lichat.Connection.write(state, Update.fail(update, Update.NoSuchProfile,
            [text: "No such profile with name #{update.from}"]))
    end
    state
  end
end
