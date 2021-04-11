defmodule RawTCP do
  @behaviour Lichat.Connection

  @impl Lichat.Connection
  def init(_data, state) do
    {:ok, %{state | type: __MODULE__}}
  end

  @impl Lichat.Connection
  def handle_payload(state, data, max_size) do
    case state.accumulator do
      :dropping ->
        case :binary.split(data, <<0>>) do
          [ _, rest ] ->
            handle_payload(%{state | accumulator: <<>>}, rest, max_size)
          _ ->
            {:more, state}
        end
      acc ->
        data = acc <> data
        case :erlang.decode_packet(:line, data, [line_length: max_size, line_delimiter: 0]) do
          {:ok, payload, rest} ->
            if :binary.last(payload) != 0 and byte_size(payload) == max_size do
              write(state, Update.fail(Update.UpdateTooLong))
              handle_payload(%{state | accumulator: :dropping}, rest, max_size)
            else
              if rest != <<>>, do: send self(), {:tcp, state.socket, rest}
              {:ok, payload, %{state | accumulator: <<>>}}
            end
          {:more, _} ->
            {:more, %{state | accumulator: data}}
          ## This case should never occur, but we handle it anyway.
          {:error, reason} ->
            write(state, Update.fail(Update.MalformedUpdate, [text: reason]))
            {:more, %{state | accumulator: :dropping}}
        end
    end
  end

  @impl Lichat.Connection
  def write(state, update) do
    Lichat.Connection.write(state, Update.print(update))
  end

  @impl Lichat.Connection
  def close(state) do
    write(state, Update.make(Update.Disconnect, [
              from: Lichat.server_name()
            ]))
    Lichat.Connection.shutdown(state)
  end
end
