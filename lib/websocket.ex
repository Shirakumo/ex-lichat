defmodule Websocket do
  import Bitwise
  require Logger
  @behaviour Lichat.Connection

  @impl Lichat.Connection
  def init(data, state) do
    if String.starts_with?(data, "GET ") do
      {:ok, %{state | type: __MODULE__, accumulator: {<<>>,<<>>}, state: :header}}
    else
      :error
    end
  end

  @impl Lichat.Connection
  def handle_payload(state, data, _max_size) do
    {accumulator, payload} = state.accumulator
    data = accumulator <> data
    case state.state do
      :header ->
        case :erlang.decode_packet(:http, data, []) do
          {:ok, _request, headers} ->
            case decode_headers(headers) do
              {:ok, rest, fields} ->
                Lichat.Connection.write(state, encode_http_response(fields[:key]))
                if(rest != <<>>, do: send(self(), {:tcp, state.socket, rest}))
                {:more, %{state | accumulator: {<<>>, <<>>}, state: nil, ip: Map.get(fields, :ip, state.ip)}}
              {:more, _} ->
                {:more, %{state | accumulator: {data, <<>>}}}
              {:error, reason} ->
                {:error, reason, state}
            end
          {:more, _} -> 
            {:more, %{state | accumulator: {data, <<>>}}}
          {:error, reason} -> 
            {:error, reason, state}
        end
      _ ->
        case decode_frame(data) do
          {:ok, fin, opcode, data, rest} ->
            payload = payload <> data
            case opcode do
              8 ->
                write(state, 8, <<>>)
                {:more, Lichat.Connection.shutdown(state)}
              9 ->
                write(state, 10, payload)
                {:more, %{state | accumulator: {rest, <<>>}}}
              10 ->
                {:more, %{state | accumulator: {rest, <<>>}}}
              _ ->
                case fin do
                  0 ->
                    {:more, %{state | accumulator: {rest, payload}}}
                  1 ->
                  ## Trigger a new empty packet to ensure we are called again in case
                  ## we have a complete packet remaining.
                    if(rest != <<>>, do: send(self(), {:tcp, state.socket, <<>>}))
                    {:ok, payload, %{state | accumulator: {rest, <<>>}}}
                end
            end
          :more ->
            {:more, %{state | accumulator: {data, payload}}}
          :error ->
            {:error, "Bad packet", state}
        end
    end
  end

  @impl Lichat.Connection
  def write(state, update) do
    write(state, 1, Update.print(update))
  end

  @impl Lichat.Connection
  def close(state) do
    write(state, 8, <<>>)
    Lichat.Connection.shutdown(state)
  end

  defp encode_http_response(key) do
    "HTTP/1.1 101 Switching Protocols\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Accept: " <> websocket_key(key) <> "\r
Sec-WebSocket-Protocol: lichat\r
\r\n"
  end

  defp websocket_key(key) do
    Base.encode64(:crypto.hash(:sha, key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
  end

  defp decode_headers(string) do
    decode_headers(:erlang.decode_packet(:httph, string, []), %{})
  end

  defp decode_headers({:ok, :http_eoh, rest}, state) do
    if state[:upgrade] == true and state[:connection] == true and state[:key] != nil do
      {:ok, rest, state}
    else
      {:error, "Missing fields"}
    end
  end
  
  defp decode_headers({:ok, {:http_header, _, _, field, value}, rest}, state) do
    state =  case field do
               ~c"Upgrade" ->
                 Map.put(state, :upgrade, value == ~c"websocket")
               ~c"Connection" ->
                 Map.put(state, :connection, String.contains?(List.to_string(value), "Upgrade"))
               ~c"Sec-WebSocket-Key" ->
                 Map.put(state, :key, List.to_string(value))
               ~c"X-Forwarded-For" ->
                 Logger.info("Websocket forwarded: #{inspect(value)}")
                 case :inet.parse_ipv6_address(Enum.take_while(value, &(&1 != ?,))) do
                   {:ok, ip} -> Map.put(state, :ip, ip)
                   _ -> state
                 end
               _ -> state
             end
    decode_headers(rest, state)
  end
  
  defp decode_headers(string, state) when is_binary(string) do
    decode_headers(:erlang.decode_packet(:httph, string, []), state)
  end

  defp decode_headers(result, _), do: result
  
  defp write(state, opcode, data) do
    Lichat.Connection.write(state, encode_frame(opcode, data))
  end

  defp encode_frame(opcode, data) do
    size = byte_size(data)
    cond do
      size <= 125     -> <<1::1, 0::3, opcode::4, 0::1, size::7, data::binary>>
      size < 1 <<< 16 -> <<1::1, 0::3, opcode::4, 0::1, 126::7, size::16, data::binary>>
      size < 1 <<< 64 -> <<1::1, 0::3, opcode::4, 0::1, 127::7, size::64, data::binary>>
      true -> raise "Payload too big to send in one frame."
    end
  end

  defp decode_frame({fin, opcode, len, key, payload}) do
    if len <= byte_size(payload) do
      {payload, rest} = :erlang.split_binary(payload, len)
      unmasked = unmask(payload, key, len)
      {:ok, fin, opcode, unmasked, rest}
    else
      :more
    end
  end
  
  ## Extended length 2
  defp decode_frame(<<fin::1, _::3, opcode::4, 1::1, 127::7, len::64, key::32, payload :: binary>>) do
    decode_frame({fin, opcode, len, key, payload})
  end
  ## Extended length 1
  defp decode_frame(<<fin::1, _::3, opcode::4, 1::1, 126::7, len::16, key::32, payload :: binary>>) do
    decode_frame({fin, opcode, len, key, payload})
  end
  ## Standard length
  defp decode_frame(<<fin::1, _::3, opcode::4, 1::1, len::7, key::32, payload :: binary>>) do
    decode_frame({fin, opcode, len, key, payload})
  end
  defp decode_frame(<<header::16, _key::32, _payload :: binary>>) do
    IO.inspect(header, binaries: :as_binaries)
    :error
  end
  defp decode_frame(_) do
    :more
  end

  defp unmask(data, nil, _), do: data
  defp unmask(data, key, 0), do: mask(data, key, <<>>)
  defp unmask(data, key, _len), do: mask(data, key, <<>>)

  defp mask(<<>>, _, unmasked), do: unmasked
  defp mask(<<o::32, rest::bits>>, key, acc) do
    t = bxor(o, key)
    mask(rest, key, <<acc::binary, t::32>>)
  end
  defp mask(<<o::24>>, key, acc) do
    <<key::24, _::8>> = <<key::32>>
    t = bxor(o, key)
    <<acc::binary, t::24>>
  end
  defp mask(<<o::16>>, key, acc) do
    <<key::16, _::16>> = <<key::32>>
    t = bxor(o, key)
    <<acc::binary, t::16>>
  end
  defp mask(<<o::8>>, key, acc) do
    <<key::8, _::24>> = <<key::32>>
    t = bxor(o, key)
    <<acc::binary, t::8>>
  end
end
