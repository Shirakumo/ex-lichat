defmodule LDAPProfile do
  @behaviour Profile
  require Logger
  use Agent

  @impl Profile
  def start_link(opts) do
    Agent.start_link(fn ->
      connection = connect(config(:bind_dn), config(:bind_pw))
      Logger.info("Connected to LDAP server at #{inspect(config(:host))}")
      connection
    end, opts)
  end

  defp config(key), do: Application.fetch_env!(:lichat, LDAPProfile)[key]

  defp connect() do
    case :eldap.open([config(:host)],
          [ssl: config(:ssl),
           port: config(:port),
           timeout: config(:timeout)]) do
      {:ok, conn} ->
        :eldap.controlling_process(conn, self())
        {:ok, conn}
      {:error, reason} ->
        Logger.info("Failed to connect to LDAP server: #{to_string(reason)}")
        {:error, reason}
    end
  end

  defp bind(conn, dn, pw) do
    :eldap.simple_bind(conn, :binary.bin_to_list(dn), :binary.bin_to_list(pw))
  end

  defp connect(dn, pw) do
    case connect() do
      {:ok, conn} ->
        case bind(conn, dn, pw) do
          :ok -> 
            {:ok, conn, dn, pw}
          {:error, _} ->
            :eldap.close(conn)
            {:error, dn, pw}
        end
      _ ->
        {:error, dn, pw}
    end
  end

  defp reconnect({:ok, conn, dn, pw}) do
    :eldap.close(conn)
    connect(dn, pw)
  end

  defp reconnect({:error, dn, pw}) do
    connect(dn, pw)
  end

  defp find({:ok, conn, _, _}, dn) do
    case :eldap.search(conn,
          filter: :eldap.present(:binary.bin_to_list(config(:account_identifier))),
          base: :binary.bin_to_list(dn),
          scope: :eldap.baseObject) do
      {:ok, {:eldap_search_result, [entry], _}} -> {:ok, entry}
      _ -> :not_registered
    end
  end

  defp find({:error, _, _}, _) do
    :not_registered
  end

  defp dn(user) do
    config(:account_identifier) <> "=" <> user <> "," <> config(:base)
  end

  @impl Profile
  def reload(server) do
    Agent.update(server, &reconnect/1)
  end

  @impl Profile
  def lookup(server, name) do
    Agent.get(server, &find(&1, dn(name)))
  end

  @impl Profile
  def check(server, name, password) do
    ## This might be bad for spam...
    case connect(dn(name), password) do
      {:ok, conn, _, _} ->
        :eldap.close(conn)
        :ok
      _ ->
        case lookup(server, name) do
          {:ok, _} -> :bad_password
          t -> t
        end
    end
  end

  @impl Profile
  def register(_server, _name, _password) do
    {:error, "Failed"}
  end
end
