defmodule Sql do
  require Logger
  defmodule Query do
    use AyeSQL
    defqueries("sql/channel.sql")
    defqueries("sql/connection.sql")
    defqueries("sql/history.sql")
    defqueries("sql/ip_log.sql")
    defqueries("sql/user.sql")
  end

  def start_link(opts) do
    if opts == [] do
      :ignore
    else
      case Postgrex.start_link([{:name, Sql} | opts]) do
        {:ok, pid} ->
          Logger.info("Connected to PSQL server at #{Keyword.get(opts, :hostname)}")
          case create_tables() do
            :ok -> {:ok, pid}
            x -> x
          end
        x -> x
      end
    end
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
  
  def create_channel(channel) do
    with_db("Failed to create channel entry for #{channel.name}", fn ->
      handle_create(Query.create_channel(
            name: channel.name,
            registrant: channel.registrant,
            lifetime: channel.lifetime,
            expiry: channel.expiry))
    end)
  end

  def delete_channel(channel) do
    with_db("Failed to delete channel #{channel.name}", fn ->
      Query.delete_channel(name: channel.name)
    end)
  end
  
  def create_user(user) do
    with_db("Failed to create user #{user.name}", fn ->
      handle_create(Query.create_user(
            name: user.name,
            registered: Profile.registered?(user.name),
            created_on: Toolkit.universal_time()))
    end)
  end

  def delete_user(user) do
    with_db("Failed to delete user #{user.name}", fn ->
      Query.delete_user(name: user.name)
    end)
  end

  def update_user(user, last_connected \\ Toolkit.universal_time()) do
    with_db("Failed to delete user #{user.name}", fn ->
      Query.update_user(name: user.name, last_connected: last_connected)
    end)
  end

  def join_channel(channel, user) do
    with_db("Failed to join user #{user} to #{channel}", fn ->
      Query.join_channel(channel: channel, user: user)
    end)
  end

  def leave_channel(channel, user) do
    with_db("Failed to leave user #{user} from #{channel}", fn ->
      Query.leave_channel(channel: channel, user: user)
    end)
  end

  def create_connection(connection) do
    with_db("Failed to create connection #{Lichat.Connection.describe(connection)}", fn ->
      case Query.create_connection(
            ip: connection.ip,
            ssl: connection.ssl,
            user: connection.name,
            last_update: connection.last_update,
            started_on: connection.started_on) do
        {:ok, ok} -> ok
        x -> x
      end
    end)
  end

  def delete_connection(connection) do
    with_db("Failed to delete connection #{Lichat.Connection.describe(connection)}", fn ->
      Query.delete_connection(id: connection.sql_id)
    end)
  end

  def update_connection(connection) do
    with_db("Failed to update connection #{Lichat.Connection.describe(connection)}", fn ->
      Query.update_connection(id: connection.sql_id, last_update: connection.last_update)
    end)
  end

  def with_db(f) do
    if Process.whereis(Sql) != nil do
      f.()
    else
      {:error, :not_connected}
    end
  end

  def with_db(faillog, f) do
    if Process.whereis(Sql) != nil do
      case f.() do
        {:error, error} ->
          Logger.error("[Sql] #{faillog}: #{inspect(error)}")
          {:error, error}
        x -> x
      end
    else
      {:error, :not_connected}
    end
  end

  defp create_tables() do
    [&Query.create_channels_table/1,
     &Query.create_channel_members_table/1,
     &Query.create_connections_table/1,
     &Query.create_connections_ip_index/1,
     &Query.create_connections_user_index/1,
     &Query.create_history_table/1,
     &Query.create_history_text_index/1,
     &Query.create_history_user_index/1,
     &Query.create_history_channel_index/1,
     &Query.create_ip_log_table/1,
     &Query.create_ip_log_ip_index/1,
     &Query.create_ip_log_user_index/1,
     &Query.create_ip_log_action_index/1,
     &Query.create_users_table/1]
     |> Enum.map(&(&1.()))
     |> Enum.all?(fn {x, _} -> x == :ok end)
  end
  
  defp handle_create(response) do
    case response do
      %Postgrex.Error{message: _, postgres: detail, connection_id: _, query: _} ->
        case detail.code do
          :unique_violation -> :ok
          _ -> {:error, detail}
        end
      result -> result
    end
  end
end
