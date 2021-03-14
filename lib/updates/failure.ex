use Update

defupdate Failure, "FAILURE",
  [[:text, default: "An unknown failure occurred."]]
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
