defmodule Users do
  use DynamicSupervisor
  
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    Registry.start_link(name: User, keys: :unique)
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(opts) do
    DynamicSupervisor.start_child(__MODULE__, %{id: User, start: {User, :start_link, opts}, restart: :transient})
  end
end
