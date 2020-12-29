import Config

config :lichat,
  allowed_content_types: ["image/png", "image/jpeg", "image/gif", "image/svg+xml",
                          "audio/webm", "audio/ogg", "audio/mpeg", "audio/mp3", "audio/mp4", "audio/flac",
                          "video/webm", "video/ogg", "video/mp4",
                          "application/ogg"],
  max_connections_per_user: 20,
  max_update_size: 8388608,
  channel_lifetime: 5184000,
  profile_lifetime: 31536000,
  ip: {0,0,0,0},
  port: 1111,
  acceptors: 2,
  server_name: "Lichat",
  profiles: [LDAPProfile, LocalProfile]

import_config "secret.exs"
