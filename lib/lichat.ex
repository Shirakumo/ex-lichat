defmodule Lichat do
  require Logger
  use Application

  def protocol_version, do: "2.0"
  def protocol_extensions, do: []

  @impl true
  def start(_type, _args) do
    Toolkit.init()
    
    children = [
      {Task.Supervisor, name: Connection.Supervisor},
      {Profile, name: Profile},
      {Registry, name: User, keys: :unique},
      {Server,
       port: Toolkit.config(:port, 1111),
       acceptors: Toolkit.config(:acceptors, 2),
       supervisor: Connection.Supervisor}
    ]

    opts = [strategy: :one_for_one, name: Lichat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
