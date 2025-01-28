defmodule History do
  def limit, do: 100

  def record(update) do
    case update.type.__struct__ do
      Update.React ->
        Sql.with_db("Failed to record update", fn ->
          Sql.Query.history_record(
            id: to_string(update.id),
            clock: update.clock,
            from: update.from,
            bridge: Map.get(update.type, :bridge),
            channel: update.type.channel,
            text: update.type.emote,
            rich: update.type.target <> "  " <> to_string(update.type.update_id),
            markup: "text/x-lichat-reaction")
        end)
      Update.Message ->
        rich = case Map.get(update.type, :rich) do
                 nil -> nil
                 x -> WireFormat.print1(x)
               end
        Sql.with_db("Failed to record update", fn ->
          Sql.Query.history_record(
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
          end)
      _ -> {:error, {:unsupported_update_type, update.type.__struct__}}
    end
    
  end

  def clear(channel) do
    Sql.with_db("Failed to clear channel history", fn ->
      Sql.Query.history_clear(channel: channel)
    end)
  end

  def backlog(channel, since \\ 0, limit \\ 100) do
    Sql.with_db(fn ->
      map_result(Sql.Query.history_backlog(channel: channel, since: since, limit: limit))
    end)
  end
  
  def search(channel, query, offset \\ 0) do
    Sql.with_db(fn ->
      from = Toolkit.getf(query, :from)
      text = Toolkit.getf(query, :text)
      [time_min, time_max] = Toolkit.getf(query, :clock, [true, true])
      map_result(Sql.Query.history_search(
            channel: channel,
            from: ensure_regex(from),
            time_min: ensure_time(time_min),
            time_max: ensure_time(time_max),
            text: ensure_regex(text),
            limit: limit(),
            offset: offset))
    end)
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
end
