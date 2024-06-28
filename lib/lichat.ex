defmodule Lichat do
  require Logger
  use Application
  @version Mix.Project.config[:version]

  def version, do: "2.0"
  def server_version, do: @version

  def compatible_versions, do: [ "2.0", "1.5", "1.4", "1.3", "1.2", "1.1", "1.0" ]

  def extensions, do: ["shirakumo-data", "shirakumo-emotes", "shirakumo-edit", "shirakumo-channel-info",
                       "shirakumo-pause", "shirakumo-quiet", "shirakumo-server-management", "shirakumo-ip",
                       "shirakumo-channel-trees", "shirakumo-backfill", "shirakumo-user-info",
                       "shirakumo-icon", "shirakumo-bridge", "shirakumo-reactions", "shirakumo-block",
                       "shirakumo-search", "shirakumo-link", "shirakumo-last-read", "shirakumo-typing",
                       "shirakumo-replies"]
  
  def compatible?(version) do
    Enum.member?(compatible_versions(), version)
  end

  def server_name, do: Toolkit.config(:server_name, "Lichat")

  @impl true
  def start(_type, _args) do
    Toolkit.init()
    
    children = [
      {Task.Supervisor, name: Connection.Supervisor},
      {History, Toolkit.config(History, [])},
      {Users, name: Users},
      {Channels, name: Channels},
      {Profile, name: Profile},
      {Blacklist, name: Blacklist},
      Init,
      {Server,
       listeners: Toolkit.config(:listen, []),
       supervisor: Connection.Supervisor}
    ]

    opts = [strategy: :one_for_one, name: Lichat.Supervisor]
    pid = Supervisor.start_link(children, opts)
    
    System.at_exit(fn _ ->
      notify("Server shutting down...")
      offload()
    end)

    pid
  end

  def notify(message) do
    Logger.info(message)
    Channel.write_sync(Channel.primary(), Update.make(Update.Message, [
              channel: server_name(),
              from: server_name(),
              text: message
            ]))
  end

  def restart() do
    notify("Server going down for restart shortly...")
    offload()
    System.stop(221)
  end

  def offload() do
    Channels.offload()
    Blacklist.offload()
    LocalProfile.offload(LocalProfile)
  end

  def reload() do
    ## TODO: ssl reload
    Profile.reload()
    Blacklist.reload()
  end
end
