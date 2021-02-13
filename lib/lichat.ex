defmodule Lichat do
  require Logger
  use Application

  def version, do: "2.0"

  def compatible_versions, do: [ "2.0", "1.5", "1.4", "1.3", "1.2", "1.1", "1.0" ]

  def extensions, do: ["shirakumo-data", "shirakumo-emotes", "shirakumo-edit", "shirakumo-channel-info",
                       "shirakumo-pause", "shirakumo-quiet", "shirakumo-server-management", "shirakumo-ip",
                       "shirakumo-channel-trees", "shirakumo-backfill", "shirakumo-user-info",
                       "shirakumo-icon"]
  
  def compatible?(version) do
    Enum.member?(compatible_versions(), version)
  end

  def server_name, do: Toolkit.config(:server_name, "Lichat")

  @impl true
  def start(_type, _args) do
    Toolkit.init()
    
    children = [
      {Task.Supervisor, name: Connection.Supervisor},
      {Users, name: Users},
      {Channels, name: Channels},
      {Profile, name: Profile},
      {Emote, name: Emote},
      {Blacklist, name: Blacklist},
      {Server,
       listeners: Toolkit.config(:listen, []),
       supervisor: Connection.Supervisor}
    ]

    opts = [strategy: :one_for_one, name: Lichat.Supervisor]
    pid = Supervisor.start_link(children, opts)

    Channels.reload()
    Channel.ensure_channel()
    User.ensure_user()
    
    System.at_exit(fn _ ->
      Channels.offload()
      Blacklist.offload()
      LocalProfile.offload(LocalProfile)
    end)

    pid
  end
end
