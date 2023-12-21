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
    modules = Toolkit.push_new(Toolkit.config!(:profiles), LocalProfile)
    children = Enum.map(modules, &Supervisor.child_spec({&1, [name: &1]}, id: &1))
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
          if module in Toolkit.config!(:profiles) do
            fun.(module, pid)
          else
            nil
          end
        end) do
      nil -> default
      x -> x
    end
  end

  def valid_info?(symbol) do
    Symbol.is_symbol(symbol)
    and symbol.package == :keyword
    and Enum.member?(["BIRTHDAY", "CONTACT", "LOCATION", "PUBLIC-KEY", "REAL-NAME", "STATUS", "ICON"], symbol.name)
  end

  def valid_info?(symbol, value) do
    Toolkit.valid_info?(symbol, value)
  end

  def info(name) do
    name = String.downcase(name)
    LocalProfile.info(LocalProfile, name)
  end

  def info(name, key, value) do
    value = Toolkit.optimize_info_value(key, value)
    name = String.downcase(name)
    LocalProfile.ensure(LocalProfile, name)
    LocalProfile.info(LocalProfile, name, key, value)
  end

  def blocked(name) do
    LocalProfile.blocked(LocalProfile, name)
  end

  def block(name, target) do
    name = String.downcase(name)
    LocalProfile.ensure(LocalProfile, name)
    LocalProfile.block(LocalProfile, name, target)
  end

  def unblock(name, target) do
    name = String.downcase(name)
    LocalProfile.ensure(LocalProfile, name)
    LocalProfile.unblock(LocalProfile, name, target)
  end

  def lookup(name) do
    name = String.downcase(name)
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
    name = String.downcase(name)
    find_child(fn module, pid ->
      case module.check(pid, name, password) do
        :ok -> :ok
        :bad_password -> :bad_password
        _ -> nil
      end
    end, :not_registered)
  end

  def register(name, password) do
    name = String.downcase(name)
    find_child(fn module, pid ->
      case module.register(pid, name, password) do
        :ok -> :ok
        :ignore -> nil
        t -> t
      end
    end, {:error, "Cannot register"})
  end
end
