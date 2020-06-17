defmodule Lichat do
  require Logger
  use Application

  def protocol_version, do: "2.0"

  @impl true
  def start(_type, _args) do
    Toolkit.init()
    
    port = String.to_integer(System.get_env("PORT") || "1111")

    children = [
      {Task.Supervisor, name: Connection.Supervisor},
      {Server, port: port}
    ]

    opts = [strategy: :one_for_one, name: Lichat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
