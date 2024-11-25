defmodule History do
  require Logger
  defmodule Pool do
  end
  defmodule Query do
    use Yesql, driver: Postgrex, conn: History
    Yesql.defquery("lib/sql/create_history_channels_table.sql")
    Yesql.defquery("lib/sql/create_history_table.sql")
    Yesql.defquery("lib/sql/create_iplog_table.sql")
    Yesql.defquery("lib/sql/create.sql")
    Yesql.defquery("lib/sql/search.sql")
    Yesql.defquery("lib/sql/backlog.sql")
    Yesql.defquery("lib/sql/record.sql")
    Yesql.defquery("lib/sql/clear.sql")
    Yesql.defquery("lib/sql/ip_log.sql")
    Yesql.defquery("lib/sql/ip_search.sql")
  end
  
  def limit, do: 100

  def start_link(opts) do
    if opts == [] do
      :ignore
    else
      case Postgrex.start_link([{:name, History} | opts]) do
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

  def create_tables() do
    with {:ok, _} <- Query.create_history_channels_table([]),
         {:ok, _} <- Query.create_history_table([]),
         {:ok, _} <- Query.create_iplog_table([]) do
      :ok
    end
  end

  def ip_log(connection, action, target \\ nil) do
    if Process.whereis(History) != nil do
      Query.ip_log(
        ip: Toolkit.ip(connection.ip),
        clock: Toolkit.universal_time(),
        action: action_id(action),
        from: connection.name,
        target: target)
    else
      {:error, :not_connected}
    end
  end

  def ip_search(ip \\ nil, opts \\ [])
  
  def ip_search(ip, opts) do
    if Process.whereis(History) != nil do
      map_ip_result(Query.ip_search(
            ip: if(is_nil(ip), do: nil, else: Toolkit.ip(ip)),
            from: Keyword.get(opts, :from, nil),
            action: action_id(Keyword.get(opts, :action, Update)),
            limit: Keyword.get(opts, :count, 100),
            offset: Keyword.get(opts, :start, 0)))
    else
      {:error, :not_connected}
    end
  end

  def create(channel) do
    if Process.whereis(History) != nil do
      case Query.create(channel: channel) do
        %Postgrex.Error{message: _, postgres: detail, connection_id: _, query: _} ->
          case detail.code do
            :unique_violation -> :ok
            _ -> {:error, detail}
          end
        result -> result
      end
    else
      {:error, :not_connected}
    end
  end

  def record(update) do
    if Process.whereis(History) != nil do
      case update.type.__struct__ do
        Update.React ->
          Query.record(
            id: to_string(update.id),
            clock: update.clock,
            from: update.from,
            bridge: Map.get(update.type, :bridge),
            channel: update.type.channel,
            text: update.type.emote,
            rich: update.type.target <> "  " <> to_string(update.type.update_id),
            markup: "text/x-lichat-reaction")
        Update.Message ->
          rich = case Map.get(update.type, :rich) do
                   nil -> nil
                   x -> WireFormat.print1(x)
                 end
          Query.record(
            id: to_string(update.id),
            clock: update.clock,
            from: update.from,
            bridge: Map.get(update.type, :bridge),
            channel: update.type.channel,
            text: update.type.text,
            rich: rich,
            markup: if rich == nil do
              Map.get(update.type, :link)
            else
              "text/shirakumo-lichat-markup"
            end)
          _ -> {:error, :unsupported_update_type}
      end
    else
      {:error, :not_connected}
    end
  end

  def clear(channel) do
    if Process.whereis(History) != nil do
      Query.clear(channel: channel)
    else
      {:error, :not_connected}
    end
  end

  def backlog(channel, since \\ 0, limit \\ 100) do
    if Process.whereis(History) != nil do
      map_result(Query.backlog(channel: channel, since: since, limit: limit))
    else
      {:error, :not_connected}
    end
  end
  
  def search(channel, query, offset \\ 0) do
    if Process.whereis(History) != nil do
      from = Toolkit.getf(query, :from)
      text = Toolkit.getf(query, :text)
      [time_min, time_max] = Toolkit.getf(query, :clock, [true, true])
      map_result(Query.search(
            channel: channel,
            from: ensure_regex(from),
            time_min: ensure_time(time_min),
            time_max: ensure_time(time_max),
            text: ensure_regex(text),
            limit: limit(),
            offset: offset))
    else
      {:error, :not_connected}
    end
  end

  defp map_result({:ok, results}), do: Enum.map(results, &map_result/1)
  defp map_result({:error, e}), do: {:error, e}

  defp map_result(map) do
    cond do
      map.markup == "text/x-lichat-reaction" ->
        [target, update_id] = String.split(map[:rich], "  ")
        Update.make(Update.React, [
              id: map.id,
              clock: map.clock,
              from: map.from,
              channel: map.name,
              target: target,
              update_id: update_id,
              emote: map.text])
      map.markup == "text/shirakumo-lichat-markup" ->
          Update.make(Update.Message, [
              id: map.id,
              clock: map.clock,
              from: map.from,
              bridge: map.bridge,
              channel: map.name,
              text: map.text,
              rich: case WireFormat.parse1(map.rich) do
                      {:ok, x} -> x
                      _ -> nil
                    end])
      Enum.member?(Toolkit.config(:allowed_content_types), map.markup) ->
        Update.make(Update.Message, [
              id: map.id,
              clock: map.clock,
              from: map.from,
              bridge: map.bridge,
              channel: map.name,
              text: map.text,
              link: map.markup])
      true ->
          Update.make(Update.Message, [
              id: map.id,
              clock: map.clock,
              from: map.from,
              bridge: map.bridge,
              channel: map.name,
              text: map.text])
    end
  end

  defp ensure_time(true), do: nil
  defp ensure_time(time), do: time

  defp escape_regex_char(x) do
    if x in ~c"-[]{}()+?.\\^$|#*" do
      [x, ?\\]
    else
      [x]
    end
  end

  defp repchar(?\\, x), do: escape_regex_char(x)
  defp repchar(_, ?\\), do: []
  defp repchar(_, ?*), do: ~c"*."
  defp repchar(_, ?_), do: ~c"."
  defp repchar(_, x), do: escape_regex_char(x)

  defp ensure_regex(nil), do: nil
  defp ensure_regex([part]), do: ensure_regex(part)
  defp ensure_regex([part | rest]) do
    <<ensure_regex(part)::binary, "|", ensure_regex(rest)::binary>>
  end
  defp ensure_regex(part) do
    {_, acc} = Enum.reduce(String.to_charlist(part), {?x, []}, fn c, {p, acc} ->
      {c, repchar(p, c) ++ acc}
    end)
    to_string(Enum.reverse(acc))
  end

  defp action_id_map, do: [
    Update.Connect,
    Update.Disconnect,
    Update.TooManyConnections,
    Update.InvalidPassword,
    Update.UsernameTaken,
    Update.NoSuchProfile,
    Update.Register,
    Update.Create,
    Update.Ban,
    Update.Unban,
    Update.IpBan,
    Update.IpUnban,
    Update.Block,
    Update.Unblock,
    Update.Destroy,
    Update.Kill,
    Update.Permissions,
    Update.SetChannelInfo,
    Update.SetUserInfo,
    Update.AssumeIdentity,
    Update.ShareIdentity,
    Update.Bridge ]
  defp action_id(action), do: Enum.find_index(action_id_map(), fn x -> x == action end)
  defp id_action(id), do: Enum.at(action_id_map(), id)

  defp map_ip_result({:ok, results}), do: Enum.map(results, &map_ip_result/1)
  defp map_ip_result({:error, e}), do: {:error, e}
  
  defp map_ip_result(map) do
    [
      id: map.id,
      ip: map.ip,
      clock: map.clock,
      action: id_action(map.action),
      from: map.from,
      target: map.target
    ]
  end
end
