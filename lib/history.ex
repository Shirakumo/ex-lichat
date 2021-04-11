defmodule History do
  require Logger
  defmodule Pool do
  end
  defmodule Query do
    use Yesql, driver: Postgrex, conn: History
    Yesql.defquery("lib/sql/create_history_channels_table.sql")
    Yesql.defquery("lib/sql/create_history_table.sql")
    Yesql.defquery("lib/sql/create.sql")
    Yesql.defquery("lib/sql/search.sql")
    Yesql.defquery("lib/sql/backlog.sql")
    Yesql.defquery("lib/sql/record.sql")
    Yesql.defquery("lib/sql/clear.sql")
  end
  
  def limit, do: 100

  def start_link(opts) do
    if opts == [] do
      :ignore
    else
      case Postgrex.start_link([{:name, History} | opts]) do
        {:ok, pid} ->
          Logger.info("Connected to PSQL server at #{Keyword.get(opts, :hostname)}")
          Query.create_history_channels_table([])
          Query.create_history_table([])
          {:ok, pid}
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

  def create(channel) do
    Query.create(channel: channel)
  end

  def record(update) do
    Query.record(
      id: to_string(update.id),
      clock: update.clock,
      from: update.from,
      bridge: Map.get(update.type, :bridge),
      channel: update.type.channel,
      text: update.type.text,
      rich: Map.get(update.type, :rich),
      markup: Map.get(update.type, :markup))
  end

  def clear(channel) do
    Query.clear(channel: channel)
  end

  def backlog(channel, limit \\ 100) do
    map_result(Query.backlog(channel: channel, limit: limit))
  end
  
  def search(channel, query, offset \\ 0) do
    from = Toolkit.getf(query, :from)
    text = Toolkit.getf(query, :text)
    [time_min, time_max] = Toolkit.getf(query, :clock, [true, true])
    map_result(Query.search(
          channel: channel,
          from: from,
          time_min: ensure_time(time_min),
          time_max: ensure_time(time_max),
          text: ensure_regex(text),
          limit: limit(),
          offset: offset))
  end

  defp map_result({:ok, results}), do: Enum.map(results, &map_result/1)
  defp map_result({:error, _}), do: []

  defp map_result(map) do
    Update.make(Update.Message, [
          id: map[:id],
          clock: map[:clock],
          from: map[:from],
          bridge: map[:bridge],
          channel: map[:name],
          text: map[:text]])
  end

  defp ensure_time(true), do: nil
  defp ensure_time(time), do: time

  defp escape_regex_char(x) do
    if x in '-[]{}()+?.\\^$|#*' do
      [x, ?\\]
    else
      [x]
    end
  end

  defp repchar(?\\, x), do: escape_regex_char(x)
  defp repchar(_, ?\\), do: []
  defp repchar(_, ?*), do: '*.'
  defp repchar(_, ?_), do: '.'
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
