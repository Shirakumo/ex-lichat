defmodule IRC do
  @behaviour Connection

  @impl Connection
  def init(data, state) do
    {:ok, %{state | type: __MODULE__}}
  end

  @impl Connection
  def handle_payload(state, data, _max_size) do
    
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

  def encode(_state, Update.Failure, update) do
    encode_failure("400", update, [""])
  end

  def encode(_state, Update.MalformedUpdate, update) do
    encode_failure("400", update, [""])
  end

  def encode(_state, Update.UpdateTooLong, update) do
    encode_failure("400", update, [""])
  end

  def encode(_state, Update.NoSuchUser, update) do
    encode_failure("401", update, [""])
  end

  def encode(_state, Update.NoSuchChannel, update) do
    encode_failure("403", update, [""])
  end

  def encode(_state, Update.InvalidUpdate, update) do
    encode_failure("421", update, [""])
  end

  def encode(_state, Update.BadName, update) do
    encode_failure("432", update, [""])
  end

  def encode(_state, Update.UsernameTaken, update) do
    encode_failure("433", update, [""])
  end

  def encode(_state, Update.NotInChannel, update) do
    encode_failure("442", update, [""])
  end

  def encode(_state, Update.NoSuchProfile, update) do
    encode_failure("451", update)
  end

  def encode(_state, Update.InvalidPassword, update) do
    encode_failure("464", update)
  end

  def encode(_state, Update.InsufficientPermissions, update) do
    encode_failure("481", update)
  end

  def encode(_state, _type, _update) do
    :skip
  end

  def encode_failure(type, update, parameters \\ []) do
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
