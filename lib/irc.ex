defmodule IRC do
  @behaviour Connection

  @impl Connection
  def init(data, state) do
    cond do
      String.starts_with?(data, "PASS") ->
        {:ok, %{state | type: __MODULE__, accumulator: <<>>, state: :pass}}
      String.starts_with?(data, "NICK") ->
        {:ok, %{state | type: __MODULE__, accumulator: <<>>, state: {:nick, nil}}}
      true ->
        :error
    end
  end

  @impl Connection
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
        case :erlang.decode_packet(:line, data, [line_length: max_size]) do
          {:ok, payload, rest} ->
            if :binary.last(payload) != 0 and byte_size(payload) == max_size do
              write(state, Update.fail(Update.UpdateTooLong))
              handle_payload(%{state | accumulator: :dropping}, rest, max_size)
            else
              if rest != <<>>, do: send self(), {:tcp, state.socket, rest}
              handle_line(%{state | accumulator: <<>>}, payload)
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

  def handle_line(state, data) do
    case state.state do
      :pass ->
        {:more, %{state | state: {:nick, String.slice(data, 5...256)}}}
      {:nick, pass} ->
        if String.starts_with?(data, "NICK ") do
          {:more, %{state | state: {:user, String.slice(data, 5...256), pass}}}
        else
          {:error, "Expected NICK command.", state}
        end
      {:user, nick, pass} ->
        if String.starts_with?(data, "USER ") do
          {:ok, Update.make(Update.Connect, [from: nick, password: pass, id: 0]), %{state | state: :connected}}
        else
          {:error, "Expected USER command.", state}
        end
      _ ->
        decode(state, data)
    end
  end

  def decode(state, string) do
    splitter = String.splitter(string, [' '])
    [command] = Enum.take(splitter)
    decode(state, command, splitter)
  end

  def decode(state, "JOIN", splitter) do
    
  end

  def decode(state, "PART", splitter) do

  end

  def decode(state, "PRIVMSG", splitter) do
    
  end

  def decode(state, "TOPIC", splitter) do

  end

  def decode(state, "QUIT", splitter) do

  end

  @impl Connection
  def write(state, update) do
    if update.from != state.name do
      case encode(state, update.type.__struct__, update) do
        :skip -> state
        string -> Connection.write(state, string)
      end
    else
      state
    end
  end

  def encode(_state, Update.Connect, update) do
    encode(Lichat.server_name(), "001", [update.from], "Welcome to the Lichat IRC gateway at " <> Lichat.server_name())
  end

  def encode(_state, Update.Message, update) do
    encode(update.from, "PRIVMSG", [to_channelname(update.type.channel)], update.type.message)
  end

  def encode(_state, Update.Join, update) do
    encode(update.from, "JOIN", [to_channelname(update.type.channel)])
  end

  def encode(_state, Update.Leave, update) do
    encode(update.from, "PART", [to_channelname(update.type.channel)])
  end

  def encode(_state, Update.Disconnect, update) do
    encode(update.from, "QUIT", [], "Quit: connection closed.")
  end

  def encode(_state, Update.Ping, update) do
    encode(update.from, "PING", [], Lichat.server_name())
  end

  def encode(_state, Update.Pong, update) do
    encode(update.from, "PONG", [], Lichat.server_name())
  end

  def encode(_state, Update.Failure, update) do
    encode_numeric("400", update, [""])
  end

  def encode(_state, Update.MalformedUpdate, update) do
    encode_numeric("400", update, [""])
  end

  def encode(_state, Update.UpdateTooLong, update) do
    encode_numeric("400", update, [""])
  end

  def encode(_state, Update.NoSuchUser, update) do
    encode_numeric("401", update, [""])
  end

  def encode(_state, Update.NoSuchChannel, update) do
    encode_numeric("403", update, [""])
  end

  def encode(_state, Update.InvalidUpdate, update) do
    encode_numeric("421", update, [""])
  end

  def encode(_state, Update.BadName, update) do
    encode_numeric("432", update, [""])
  end

  def encode(_state, Update.UsernameTaken, update) do
    encode_numeric("433", update, [""])
  end

  def encode(_state, Update.NotInChannel, update) do
    encode_numeric("442", update, [""])
  end

  def encode(_state, Update.NoSuchProfile, update) do
    encode_numeric("451", update)
  end

  def encode(_state, Update.InvalidPassword, update) do
    encode_numeric("464", update)
  end

  def encode(_state, Update.InsufficientPermissions, update) do
    encode_numeric("481", update)
  end

  def encode(_state, _type, _update) do
    :skip
  end

  def encode_numeric(type, update, parameters \\ []) do
    encode(Lichat.server_name(), type, [update.from | parameters], update.type.text)
  end

  def encode(source, type, parameters, trail \\ nil) do
    {:ok, stream} = StringIO.open("", [encoding: :latin1])
    IO.write(stream, ":")
    IO.write(stream, to_source(source))
    IO.write(stream, " ")
    IO.write(stream, type)
    Enum.each(parameters, fn parameter ->
      IO.write(stream, " ")
      IO.write(stream, parameter)
    end)
    if trail != nil do
      IO.write(stream, " :")
      IO.write(stream, trail)
    end
    IO.write(stream, "\r\n")
    {:ok, {_, string}} = StringIO.close(stream)
    string
  end

  def to_safe_name(name, excluded) do
    Enum.filter(name, &(&1 not in excluded))
  end

  def to_channelname(name) do
    "#" <> to_safe_name(name, [' ', ':'])
  end

  def to_source(name) do
    to_safe_name(name, [' ', ':', '#', '&'])
  end

  @impl Connection
  def close(state) do
    write(state, Update.make(Update.Disconnect, [from: state.name]))
    Connection.shutdown(state)
  end
end
