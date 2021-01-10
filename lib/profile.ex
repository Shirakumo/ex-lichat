defmodule Profile do
  require Logger
  use Supervisor

  @callback start_link(List.t) :: GenServer.on_start()
  @callback reload(pid()) :: :ok | {:error, term()}
  @callback lookup(pid(), String.t) :: {:ok, term()} | :expired | :not_registered
  @callback check(pid(), String.t, String.t | nil) :: :ok | :bad_password | :expired | :not_registered
  @callback register(pid(), String.t, String.t) :: :ok | :ignore | {:error, term()}

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = Enum.map(Toolkit.config!(:profiles), &{&1, [[]]})
    Supervisor.init(children, strategy: :one_for_one)
  end

  def reload() do
    find_child(fn module, pid ->
      module.reload(pid)
      nil
    end, nil)
  end

  defp find_child(fun, default) do
    case Enum.find_value(Supervisor.which_children(__MODULE__), fn {_, pid, _, [module]} ->
          fun.(module, pid)
        end) do
      :ok -> :ok
      nil -> default
    end
  end

  def lookup(name) do
    find_child(fn module, pid ->
      case module.lookup(pid, name) do
        {:ok, _} -> :ok
        _ -> nil
      end
    end, :not_registered)
  end

  def check(name, password) do
    password = case password do
                 false -> ""
                 nil -> ""
                 [] -> ""
                 x -> x
               end
    find_child(fn module, pid ->
      case module.check(pid, name, password) do
        :ok -> :ok
        :bad_password -> :bad_password
        _ -> nil
      end
    end, :not_registered)
  end

  def register(name, password) do
    find_child(fn module, pid ->
      case module.register(pid, name, password) do
        :ok -> :ok
        :ignore -> nil
        t -> t
      end
    end, {:error, "Cannot register"})
  end
end
