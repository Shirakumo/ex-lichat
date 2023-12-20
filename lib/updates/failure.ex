use Update

defmodule Failure do
  Module.register_attribute(Failure, :is_update?, persist: true)
  @is_update? true
  @behaviour Update
  @impl Update
  def type_symbol, do: %Symbol{name: "FAILURE", package: :lichat}
  
  defstruct text: "An unknown failure occurred."
  
  defimpl Update.Serialize, for: Failure do
    def to_list(type), do: [Symbol.kw("TEXT"), type.text]
    def from_list(_, args) do
      Update.from_list(%Update{},
        [ :type, struct(Failure, [text: Toolkit.getf(args, "TEXT")]) | args ])
    end
  end
  
  defimpl Update.Execute, for: Failure do
    def handle(_type, _update, _state) do
    end
  end
  
  def not_in_channel(connection, update) do
    Lichat.Connection.write(connection, Update.fail(update, Update.NotInChannel,
          [text: "#{update.from} is not in #{update.type.channel}"]))
  end
  
  def no_such_channel(connection, update) do
    Lichat.Connection.write(connection, Update.fail(update, Update.NoSuchChannel,
          [text: "No such channel with the name #{update.type.channel}"]))
  end

  def no_such_user(connection, update) do
    Lichat.Connection.write(connection, Update.fail(update, Update.NoSuchUser,
          [text: "No such user with the name #{update.type.target}"]))
  end

  def too_many_channels(connection, update) do
    Lichat.Connection.write(connection, Update.fail(update, Update.TooManyChannels,
            [text: "#{update.from} is already in too many channels (max: #{Toolkit.config!(:max_channels_per_user)})"]))
  end
end

defupdate MalformedUpdate, "MALFORMED-UPDATE",
  [[:text, default: "The update was malformed and could not be parsed."]]
defupdate UpdateTooLong, "UPDATE-TOO-LONG",
  [[:text, default: "The update was too long and has been dropped."]]
defupdate ConnectionUnstable, "CONNECTION-UNSTABLE",
  [[:text, default: "The connection is unstable and may be lost soon."]]
defupdate ClockSkewed, "CLOCK-SKEWED",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "Your clock appears skewed. You should synchronise your clock with a time server!"]]
defupdate TooManyConnections, "TOO-MANY-CONNECTIONS",
  [[:text, default: "There are too many connections for this user."]]
defupdate UpdateFailure, "UPDATE-FAILURE",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "Your request failed for an unknown reason."]]
defupdate InvalidUpdate, "INVALID-UPDATE",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The update class is invalid or unknown."]]
defupdate AlreadyConnected, "ALREADY-CONNECTED",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "This connection is already tied to a user."]]
defupdate UsernameMismatch, "USERNAME-MISMATCH",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The from field did not match the user."]]
defupdate IncompatibleVersion, "INCOMPATIBLE-VERSION",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The client version is not compatible with this server version."],
   [:compatible_versions, symbol: "COMPATIBLE-VERSIONS"]]
defupdate InvalidPassword, "INVALID-PASSWORD",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The password for the given user is invalid."]]
defupdate NoSuchProfile, "NO-SUCH-PROFILE",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The requested user does not seem to be registered."]]
defupdate UsernameTaken, "USERNAME-TAKEN",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The requested user name is already taken."]]
defupdate NoSuchChannel, "NO-SUCH-CHANNEL",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The requested channel does not exist."]]
defupdate TooManyChannels, "TOO-MANY-CHANNELS",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "You have already joined too many channels."]]
defupdate RegistrationRejected, "REGISTRATION-REJECTED",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The profile registration request was rejected."]]
defupdate AlreadyInChannel, "ALREADY-IN-CHANNEL",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The user is already in the requested channel."]]
defupdate NotInChannel, "NOT-IN-CHANNEL",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The user is not in the requested channel."]]
defupdate ChannelnameTaken, "CHANNELNAME-TAKEN",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The requested channel name is already taken."]]
defupdate BadName, "BAD-NAME",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The given user or channel name is not permitted."]]
defupdate InsufficientPermissions, "INSUFFICIENT-PERMISSIONS",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "You do not have sufficient permissions to perform this action."]]
defupdate InvalidPermissions, "INVALID-PERMISSIONS",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The permissions specification is invalid."]]
defupdate NoSuchUser, "NO-SUCH-USER",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The requested user does not exist."]]
defupdate TooManyUpdates, "TOO-MANY-UPDATES",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "You have been sending too many updates and have been throttled."]]
defupdate BadContentType, "BAD-CONTENT-TYPE",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "Content of the given type is not accepted by this server."],
   [:allowed_content_types, symbol: "ALLOWED-CONTENT-TYPES"]]
defupdate EmoteListFull, "EMOTE-LIST-FULL",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The list of emotes is already full."]]
defupdate NoSuchParentChannel, "NO-SUCH-PARENT-CHANNEL",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The channel you are trying to create a child channel under does not exist."]]
defupdate NoSuchChannelInfo, "NO-SUCH-CHANNEL-INFO",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The requested channel info key does not exist."],
   :key]
defupdate MalformedChannelInfo, "MALFORMED-CHANNEL-INFO",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The specified info was not of the correct format for the key."]]
defupdate NoSuchUserInfo, "NO-SUCH-USER-INFO",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The requested user info key does not exist."],
   :key]
defupdate MalformedUserInfo, "MALFORMED-USER-INFO",
  [[:update_id, symbol: "UPDATE-ID"],
   [:text, default: "The specified info was not of the correct format for the key."]]
defupdate IdentityAlreadyUsed, "IDENTITY-ALREADY-USED",
  [[:text, default: "The specified identity key is invalid or has been used already."]]

