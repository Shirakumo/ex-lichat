defmodule Blacklist do
  require Logger
  use Agent
  import Bitwise
  defstruct ips: MapSet.new(), names: MapSet.new()

  def start_link(opts) do
    ## Persist blacklist every hour.
    :timer.apply_interval(60 * 60 * 1000, Blacklist, :offload, [])
    case Agent.start_link(fn -> %Blacklist{} end, opts) do
      {:ok, pid} ->
        reload()
        {:ok, pid}
      x -> x
    end
  end

  def reload() do
    Logger.info("Reloading blacklist")
    try do
      blacklist = File.stream!(Toolkit.config(:blacklist_file))
      |> Stream.map(&String.trim/1)
      |> Stream.map(fn line ->
        cond do
          String.starts_with?(line, "ip: ") ->
            case String.split(String.replace_leading(line, "ip: ", "")) do
              [ip, mask] ->
                {:ok, ip} = ensure_ip(ip)
                {:ok, mask} = ensure_ip(mask)
                {:ip, ip, mask}
              [ip] ->
                {:ok, ip} = ensure_ip(ip)
                {:ip, ip, {0,0,0,0,0,0,0,0}}
            end
          String.starts_with?(line, "name: ") ->
            {:name, String.trim(String.replace_leading(line, "name: ", ""))}
          true ->
            :weird
        end
      end)
      |> Enum.reduce(%Blacklist{}, &parse_blacklist/2)
      Agent.update(__MODULE__, fn _ -> blacklist end)
      :ok
    rescue
      e ->
        Logger.error("Failed to load blacklist: #{inspect(e)}")
    end
  end

  def offload() do
    Logger.info("Persisting blacklist")
    blacklist = Agent.get(__MODULE__, & &1)
    ["# Format:
#  (ip: IP MASK?) | (name: NAME)
# The IP and MASK should be IPv4 or IPv6 addresses.
# 
# Block the address 1.2.3.4:
#   ip: 1.2.3.4
# or:
#   ip: 1.2.3.4 0.0.0.0
#
# Block all addresses at 1.1.1.X:
#   ip: 1.1.1.1 0.0.0.255
# or:
#   ip: ::ffff:1.1.1.1 ::00ff
#
# Block user called \"someone new\"
#   name: someone new
"]
    |> Stream.concat(Stream.map(blacklist.ips, fn {ip, mask} -> "ip: #{:inet_parse.ntoa(ip)} #{:inet_parse.ntoa(mask)}" end))
    |> Stream.concat(Stream.map(blacklist.names, fn name -> "name: #{name}" end))
    |> Stream.into(File.stream!(Toolkit.config(:blacklist_file)))
    |> Stream.run()
  end

  def list() do
    Agent.get(__MODULE__, fn blacklist -> MapSet.to_list(blacklist.names) end)
  end

  def ip_list() do
    Agent.get(__MODULE__, fn blacklist -> blacklist.ips end)
  end

  def has?(name) when is_binary(name) do
    name = String.downcase(name)
    Agent.get(__MODULE__, fn blacklist -> MapSet.member?(blacklist.names, name) end)
  end

  def has?(ip) when is_tuple(ip) do
    ip = ensure_ip(ip)
    Agent.get(__MODULE__, fn blacklist -> Enum.any?(blacklist.ips, &ip_match?(&1, ip)) end)
  end

  def add_name(name) do
    name = String.downcase(name)
    Agent.update(__MODULE__, fn blacklist -> %{blacklist | names: MapSet.put(blacklist.names, name)} end)
  end

  def delete_name(name) do
    name = String.downcase(name)
    Agent.update(__MODULE__, fn blacklist -> %{blacklist | names: MapSet.delete(blacklist.names, name)} end)
  end

  def add_ip(ip, mask \\ "::") do
    ip = ensure_ip(ip)
    mask = ensure_ip(mask)
    Agent.update(__MODULE__, fn blacklist -> %{blacklist | ips: add_ip_set(blacklist.ips, {ip, mask})} end)
  end

  def delete_ip(ip, mask \\ "::") do
    ip = ensure_ip(ip)
    mask = ensure_ip(mask)
    Agent.update(__MODULE__, fn blacklist -> %{blacklist | ips: delete_ip_set(blacklist.ips, {ip, mask})} end)
  end

  def ip_match?({{a0, a1, a2, a3, a4, a5, a6, a7}, {m0, m1, m2, m3, m4, m5, m6, m7}}, {b0, b1, b2, b3, b4, b5, b6, b7}) do
    (a0 &&& ~~~m0) == (b0 &&& ~~~m0) and
    (a1 &&& ~~~m1) == (b1 &&& ~~~m1) and
    (a2 &&& ~~~m2) == (b2 &&& ~~~m2) and
    (a3 &&& ~~~m3) == (b3 &&& ~~~m3) and
    (a4 &&& ~~~m4) == (b4 &&& ~~~m4) and
    (a5 &&& ~~~m5) == (b5 &&& ~~~m5) and
    (a6 &&& ~~~m6) == (b6 &&& ~~~m6) and
    (a7 &&& ~~~m7) == (b7 &&& ~~~m7)
  end

  defp mask_match?({ip_, mask_}, {ip, mask}) do
    ip_match?({ip, mask}, ip_) and mask_ >= mask
  end
  
  defp add_ip_set(set, entry) do
    if Enum.any?(set, &mask_match?(&1, entry)) do
      set
    else
      MapSet.new(set
      |> Stream.reject(fn {ip_, _mask} -> ip_match?(entry, ip_) end)
      |> Stream.concat([entry]))
    end
  end

  defp delete_ip_set(set, entry) do
    MapSet.new(set
    |> Stream.reject(&mask_match?(&1, entry)))
  end

  def ensure_ip(ip) when is_binary(ip), do: :inet.parse_ipv6_address(String.to_charlist(ip))
  def ensure_ip({a,b,c,d}), do: {0, 0, 0, 0, 0, 65535, (a <<< 8)+b, (c <<< 8)+d}
  def ensure_ip({a,b,c,d,e,f,g,h}), do: {a,b,c,d,e,f,g,h}

  defp parse_blacklist({:ip, ip, mask}, blacklist), do: %{blacklist | ips: MapSet.put(blacklist.ips, {ip, mask})}
  defp parse_blacklist({:name, name}, blacklist), do: %{blacklist | names: MapSet.put(blacklist.names, name)}
  defp parse_blacklist(_, blacklist), do: blacklist
end
