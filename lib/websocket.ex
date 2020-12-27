defmodule Websocket do
  use Bitwise
  @behaviour Connection

  @impl Connection
  def init(data, state) do
    if String.starts_with?(data, "GET ") do
      %{state | type: __MODULE__, payload: <<>>, state: :header}
    else
      :error
    end
  end

  @impl Connection
  def handle_payload(state, data, _max_size) do
    data = state.accumulator <> data
    case state.state do
      :header ->
        case :erlang.decode_packet(:http, data, []) do
          {:ok, _request, headers} ->
            case decode_headers(headers) do
              {:ok, rest, key} ->
                Connection.write(state, encode_http_response(key))
                {:more, %{state | accumulator: rest, state: nil}}
              :error ->
                {:more, Connection.shutdown(state)}
              {:more, _} ->
                {:more, %{state | accumulator: data}}
              {:error, _} ->
                {:more, Connection.shutdown(state)}
            end
          _ ->
            case decode_frame(data) do
              :more ->
                {:more, %{state | accumulator: data}}
              {:ok, fin, opcode, payload, rest} ->
                payload = state.payload <> payload
                case opcode do
                  8 ->
                    write(state, 8, <<>>)
                    {:more, Connection.shutdown(state)}
                  9 ->
                    write(state, 10, payload)
                    {:more, %{state | payload: <<>>, accumulator: rest}}
                  10 ->
                    {:more, %{state | payload: <<>>, accumulator: rest}}
                  _ ->
                    case fin do
                      0 -> {:more, %{state | payload: payload, accumulator: rest}}
                      1 -> {:ok, payload, %{state | payload: <<>>, accumulator: rest}}
                    end
                end
            end
        end
    end
  end

  @impl Connection
  def write(state, update) do
    write(state, 1, Update.print(update))
  end

  @impl Connection
  def close(state) do
    write(state, 8, <<>>)
    Connection.shutdown(state)
  end

  defp encode_http_response(key) do
    "HTTP/1.1 101 Switching Protocols\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Accept: " <> websocket_key(key) <> "\r
\r"
  end

  defp websocket_key(key) do
    Base.encode64(:crypto.hash(:sha, key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
  end

  defp decode_headers(string) do
    decode_headers(:erlang.decode_packet(:httph, string, []), %{})
  end

  defp decode_headers({:ok, :http_eoh, rest}, state) do
    if state[:upgrade] and state[:connection] and state[:key] do
      {:ok, rest, state[:key]}
    else
      :error
    end
  end
  
  defp decode_headers({:ok, {:http_header, _, field, _, value}, rest}, state) do
    case field do
      "Upgrade" -> decode_headers(rest, %{state | upgrade: value == "websocket"})
      "Connection" -> decode_headers(rest, %{state | connection: value == "Upgrade"})
      "Sec-Websocket-Key" -> decode_headers(rest, %{state | key: value})
      _ -> decode_headers(rest, state)
    end
  end
  
  defp decode_headers(string, state) do
    decode_headers(:erlang.decode_packet(:httph, string, []), state)
  end
  
  defp write(state, opcode, data) do
    Connection.write(state, encode_frame(opcode, data))
  end

  defp encode_frame(opcode, data) do
    size = byte_size(data)
    if size <= 125 do
      <<1::1, 0::3, opcode::4, 0::1, size::7, data::binary>>
    else
      <<1::1, 0::3, opcode::4, 0::1, 127::7, byte_size(data)::64, data::binary>>
    end
  end

  defp decode_frame({fin, opcode, len, key, payload}) do
    if len <= byte_size(payload) do
      {payload, rest} = :erlang.split_binary(payload, len)
      {:ok, fin, opcode, xor_mask(payload, len, key), rest}
    else
      :more
    end
  end
  
  ## Extended length 2
  defp decode_frame(<<fin::1, _::3, opcode::4, 1::1, 127::7, len::64, key::32, payload :: binary>>), do: decode_frame({fin, opcode, len, key, payload})
  ## Extended length 1
  defp decode_frame(<<fin::1, _::3, opcode::4, 1::1, 126::7, len::16, key::32, payload :: binary>>), do: decode_frame({fin, opcode, len, key, payload})
  ## Standard length
  defp decode_frame(<<fin::1, _::3, opcode::4, 1::1, len::7, key::32, payload :: binary>>), do: decode_frame({fin, opcode, len, key, payload})
  defp decode_frame(_), do: :more

  ## Might be terribly inefficient, idk.
  defp xor_mask(payload, len, mask), do: xor_mask(payload, len, mask, 0, "")
  defp xor_mask("", _, _, _, acc), do: acc
  defp xor_mask(_, 0, _, _, acc), do: acc
  defp xor_mask(<<a, as::binary>>, len, b, i, acc) do
    xor_mask(as, len - 1, b, rem(1 + i, 4), <<acc::binary, bxor(a, :binary.at(b, i))>>)
  end
end
