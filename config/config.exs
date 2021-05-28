import Config

config :lichat,
  ## Which mime-type should be allowed to send data for.
  allowed_content_types: ["image/png", "image/jpeg", "image/gif", "image/svg+xml",
                          "audio/webm", "audio/ogg", "audio/mpeg", "audio/mp3", "audio/mp4", "audio/flac",
                          "video/webm", "video/ogg", "video/mp4",
                          "application/ogg"],
  ## Which mime-type should be allowed for profile or channel icons.
  allowed_icon_content_types: ["image/png", "image/gif"],
  ## The maximum size of an icon (~1MB)
  max_icon_size: 1048576,
  ## How many connections a single user can have simultaneously.
  ## Note that this is not counted per-ip, but rather per-account.
  max_connections_per_user: 20,
  ## Allow 10 updates every 10s.
  max_updates_per_connection: {10, 10},
  ## Restrict users to 10 share keys.
  max_shares_per_user: 10,
  ## Around 8 MB max limit.
  max_update_size: 8388608,
  ## How many channels a user can inhabit at most.
  max_channels_per_user: 50,
  ## Keep the last 100 updates.
  channel_backlog: 100,
  ## Around 2 months of lifetime before expiry.
  channel_lifetime: 5184000,
  ## Around 1 year of lifetime before expiry.
  profile_lifetime: 31536000,
  ## Listen on all local IPs.
  listen: [[ip: {0,0,0,0}, port: 1111, acceptors: 2],
           [ip: {0,0,0,0}, port: 1112, acceptors: 2, ssl: [certfile: "config/cert.pem", keyfile: "config/key.pem"]]],
  ## The server name to use. This will occupy the server user and channel.
  server_name: "Lichat",
  ## The profile authorities to use. Can be: LDAPProfile, LocalProfile
  profiles: [LocalProfile],
  ## Directory to store files in. If null files will not be stored.
  data_directory: "data/",
  ## Link URL prefix. The following path will be appended: /{channel}/{link-id}.{file-type}
  ## Though note that the channel name may itself contain slashes. Whatever the
  ## case though, the path that is appended will match the path to the file
  ## within the data_directory .
  link_url_prefix: "https://localhost/lichat",
  ## Directory with emote files
  emote_directory: "emotes/",
  ## File to store profile data in
  profile_file: "config/profiles.dat",
  ## File to store channel data in
  channel_file: "config/channels.dat",
  ## File to store blacklist data in
  blacklist_file: "config/blacklist.txt",
  ## File to store banner in
  banner_file: "config/banner.txt"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:intent]

import_config "secret.exs"
