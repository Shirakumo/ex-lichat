defmodule Lichat do
  require Logger
  use Application

  def version, do: "2.0"

  def compatible_versions, do: [ "2.0", "1.5", "1.4", "1.3", "1.2", "1.1", "1.0" ]

  def extensions, do: ["shirakumo-data", "shirakumo-emotes", "shirakumo-edit"]
  
  def compatible?(version) do
    Enum.member?(compatible_versions(), version)
  end

  @impl true
  def start(_type, _args) do
    Toolkit.init()
    
    children = [
      {Task.Supervisor, name: Connection.Supervisor},
      {Profile, name: Profile},
      {Emote, name: Emote},
      {Registry, name: User, keys: :unique},
      {Registry, name: Channel, keys: :unique},
      {Server,
       port: Toolkit.config(:port, 1111),
       acceptors: Toolkit.config(:acceptors, 2),
       supervisor: Connection.Supervisor}
    ]

    opts = [strategy: :one_for_one, name: Lichat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
