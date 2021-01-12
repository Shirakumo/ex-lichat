import Config

config :lichat,
  ## Which mime-type should be allowed to send data for.
  allowed_content_types: ["image/png", "image/jpeg", "image/gif", "image/svg+xml",
                          "audio/webm", "audio/ogg", "audio/mpeg", "audio/mp3", "audio/mp4", "audio/flac",
                          "video/webm", "video/ogg", "video/mp4",
                          "application/ogg"],
  ## How many connections a single user can have simultaneously.
  ## Note that this is not counted per-ip, but rather per-account.
  max_connections_per_user: 20,
  ## Allow 10 updates every 10s.
  max_updates_per_connection: {10, 10},
  ## Around 8 MB max limit.
  max_update_size: 8388608,
  ## Around 2 months of lifetime before expiry.
  channel_lifetime: 5184000,
  ## Around 1 year of lifetime before expiry.
  profile_lifetime: 31536000,
  ## Listen on all local IPs.
  ip: {0,0,0,0},
  ## Default port for unsafe (no-SSL) connections.
  port: 1111,
  ## Spawn two TCP acceptor processes
  acceptors: 2,
  ## The server name to use. This will occupy the server user and channel.
  server_name: "Lichat",
  ## The profile authorities to use.
  profiles: [LDAPProfile, LocalProfile]

import_config "secret.exs"
