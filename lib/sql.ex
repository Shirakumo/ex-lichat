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
    with_db(fn ->
      case handle_create(Query.create_channel(
                name: channel.name,
                registrant: channel.registrant,
                lifetime: channel.lifetime,
                expiry: channel.expiry)) do
        {:error, error} ->
          Logger.error("Failed to create channel entry for #{channel.name}: #{inspect(error)}")
          error
        x -> x
      end
    end)
  end

  def delete_channel(channel) do
    with_db(fn ->
      case Query.delete_channel(name: channel.name) do
        {:error, error} ->
          Logger.error("Failed to delete channel entry for #{channel.name}: #{inspect(error)}")
          error
        x -> x
      end
    end)
  end
  
  def create_user(user) do
    with_db(fn ->
      handle_create(Query.create_user(
            name: user.name,
            registered: Profile.lookup(user.name) == :ok,
            created_on: Toolkit.universal_time()))
    end)
  end

  def delete_user(user) do
    with_db(fn ->
      Query.delete_user(name: user.name)
    end)
  end

  def with_db(f) do
    if Process.whereis(Sql) != nil do
      f.()
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
