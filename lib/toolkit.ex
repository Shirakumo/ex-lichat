defmodule Toolkit do
  def init() do
    :ets.new(__MODULE__, [:public, :named_table])
    :ets.insert(__MODULE__, {:hashids, Hashids.new([salt: config(:salt, ""), min_len: 5])})
  end

  def ip(ip) when is_binary(ip), do: ip
  def ip(ip) when is_list(ip), do: List.to_string(ip)
  def ip(ip) when is_tuple(ip) do
    case :inet_parse.ntoa(ip) do
      {:error, _} -> inspect(ip)
      ip -> ip(ip)
    end
  end
  
  def id() do
    :ets.update_counter(__MODULE__, :lichatID, 1, {1, 0})
  end

  def hashid() do
    [hashids: s] = :ets.lookup(__MODULE__, :hashids)
    Hashids.encode(s, id())
  end

  def time() do
    System.system_time(:second)
  end
  
  def universal_time() do
    System.os_time(:second) + 2208988800
  end

  def banner() do
    File.read!(config(:banner_file))
  end

  def random_key(length \\ 32) do
    fn -> Enum.random('abcdefghijklmnopqrstuvwxyz0123456789') end
    |> Stream.repeatedly()
    |> Enum.take(length)
    |> to_string()
  end

  def parent_name(name) do
    case String.split(name, ~r/\/[^\/]*$/, parts: 2) do
      [_] -> nil
      [parent | _] -> parent
    end
  end

  def valid_channel_name?(name) do
    valid_name?(name)
    and not String.starts_with?(name, "@")
    and not String.starts_with?(name, "/")
    and not String.ends_with?(name, "/")
    and not String.match?(name, ~r/\/\//)
  end

  def valid_name?(name) do
    String.valid?(name)
    and String.length(name) <= 32
    and not String.starts_with?(name, " ")
    and not String.ends_with?(name, " ")
    and not String.match?(name, ~r/  /)
    and Enum.all?(String.codepoints(name), &valid_name_char?/1)
  end

  def valid_name_char?(char) do
    char == " "
    or [] != Unicode.category(char) -- [:Zl, :Zp, :Zs, :Cc, :Cf, :Co, :Cs]
  end

  def valid_info?(symbol, value) do
    is_binary(value)
    and cond do
      symbol == %Symbol{package: "KEYWORD", name: "ICON"} ->
        case String.split(value) do
          [ type, b64 ] ->
            Enum.member?(Toolkit.config!(:allowed_icon_content_types), type)
            and String.length(b64) <= Toolkit.config!(:max_icon_size)
          _ -> false
        end
      true -> true
    end
  end

  def valid_emote?(channel, string) do
    Unicode.emoji?(string) or Emote.emote?(channel, string)
  end
  
  def config(key, default \\ nil) do
    case Application.fetch_env(:lichat, key) do
      :error -> default
      {:ok, x} -> x
    end
  end

  def config!(key) do
    Application.fetch_env!(:lichat, key)
  end

  def getf!(plist, key) do
    case getf(plist, key) do
      nil -> raise "Key #{key} is missing."
      x -> x
    end
  end

  def getf(plist, key, default \\ nil)
  def getf([], _key, default), do: default
  def getf(list, key, default) do
    key = extract_key(key)
    getf_(list, key, default)
  end

  defp getf_([], _key, default), do: default
  defp getf_([k, v | rs], key, default) do
    if extract_key(k) == key, do: v, else: getf_(rs, key, default)
  end

  defp extract_key(key) do
    cond do
      is_binary(key) -> key
      is_atom(key) -> String.upcase(Atom.to_string(key))
      is_struct(key) -> key.name
    end
  end

  def push_new(list, value) do
    if Enum.member?(list, value) do
      list
    else
      [ value | list ]
    end
  end

  def prune_plist([]), do: []
  def prune_plist([_k, nil | rs]), do: prune_plist(rs)
  def prune_plist([k, v | rs]), do: [k, v | prune_plist(rs)]

  def safe_write(file, content) do
    tmpname = file <> ".tmp"
    case File.write(tmpname, content) do
      :ok ->
        case File.rename(tmpname, file) do
          :ok -> :ok
          {:error, e} ->
            Logger.critical("Failed to write to #{file}: #{e}")
            File.rm(tmpname)
            {:error, e}
        end
      {:error, e} ->
        Logger.critical("Failed to write to #{file}: #{e}")
        {:error, e}
    end
  end
end
