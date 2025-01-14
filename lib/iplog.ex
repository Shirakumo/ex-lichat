defmodule IpLog do
  def record(connection, action, target \\ nil) do
    Sql.with_db("Failed to record Ip Log", fn ->
      Sql.Query.ip_log(
        ip: Toolkit.ip(connection.ip),
        clock: Toolkit.universal_time(),
        action: action_id(action),
        from: connection.name,
        target: target)
    end)
  end

  def search(ip \\ nil, opts \\ [])
  
  def search(ip, opts) do
    Sql.with_db(fn ->
      map_ip_result(Sql.Query.ip_search(
            ip: if(is_nil(ip), do: nil, else: Toolkit.ip(ip)),
            from: Keyword.get(opts, :from, nil),
            action: action_id(Keyword.get(opts, :action, Update)),
            limit: Keyword.get(opts, :count, 100),
            offset: Keyword.get(opts, :start, 0)))
    end)
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
