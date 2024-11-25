defmodule IRC do
  require Logger
  @behaviour Lichat.Connection

  @impl Lichat.Connection
  def init(data, state) do
    cond do
      Regex.match?(~r/^(CAP|PASS|NICK|USER) /i, data) ->
        {:ok, %{state | type: __MODULE__, accumulator: <<>>, state: {:init, nil, nil, nil}}}
      true ->
        :error
    end
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
        case :erlang.decode_packet(:line, data, [line_length: max_size]) do
          {:ok, payload, rest} ->
            if :binary.last(payload) != 0 and byte_size(payload) == max_size do
              write(state, Update.fail(Update.UpdateTooLong))
              handle_payload(%{state | accumulator: :dropping}, rest, max_size)
            else
              if(rest != <<>>, do: send(self(), {:tcp, state.socket, rest}))
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
    data = String.trim_trailing(data)
    next = fn pass, nick, user ->
      if nick == nil or user == nil do
        {:more, %{state | state: {:init, pass, nick, user}}}
      else
        {:ok, Update.make(Update.Connect, [from: nick,
                                           password: pass,
                                           version: Lichat.version(),
                                           extensions: ["shirakumo-link"]]),
         %{state | state: nil, name: nick}}
      end
    end
    case state.state do
      {:init, pass, nick, user} ->
        cond do
          Regex.match?(~r/^CAP /i, data) ->
            next.(pass, nick, user)
          Regex.match?(~r/^PASS /i, data) ->
            next.(String.slice(data, 5..256), nick, user)
          Regex.match?(~r/^NICK /i, data) ->
            next.(pass, from_source(String.slice(data, 5..256)), user)
          Regex.match?(~r/^USER /i, data) ->
            next.(pass, nick, true)
          true ->
            {:error, "Unknown command in init, got #{data}", state}
        end
      _ ->
        decode(state, data)
    end
  end

  def decode(state, string) do
    [command | args] = String.split(string, " ")
    decode(state, String.upcase(command), args)
  end

  def decode(state, "JOIN", [chan | _]) do
    {:more, Enum.reduce(String.split(chan, ","), state, fn name, state ->
        name = from_channelname(name)
        Lichat.Connection.handle_update(state,
          case Channel.get(name) do
            {:ok, _} -> Update.make(Update.Join, [id: Toolkit.id(), from: state.name, channel: name])
            :error -> Update.make(Update.Create, [id: Toolkit.id(), from: state.name, channel: name])
          end)
      end)}
  end

  def decode(state, "PART", [chan | _]) do
    {:more, Enum.reduce(String.split(chan, ","), state, fn chan, state ->
        Lichat.Connection.handle_update(state,
          Update.make(Update.Leave, [id: Toolkit.id(), from: state.name, channel: from_channelname(chan)]))
      end)}
  end

  def decode(state, "PRIVMSG", [chan | args]) do
    text = strip_prefix(Enum.join(args, " "))
    case text do
      <<1, "ACTION", payload::binary>> ->
        reply_update(state, Update.Message, [channel: from_channelname(chan), text: "*"<>state.name<>" "<>String.slice(payload,1..-1//1)<>"*"])
      payload ->
        reply_update(state, Update.Message, [channel: from_channelname(chan), text: payload])
    end
  end

  def decode(state, "TOPIC", [chan | _]) do
    reply_update(state, Update.ChannelInfo, [channel: from_channelname(chan), keys: [Symbol.kw("TOPIC")]])
  end

  def decode(state, "QUIT", _args) do
    reply_update(state, Update.Disconnect)
  end

  def decode(state, "PING", _args) do
    reply_update(state, Update.Ping)
  end

  def decode(state, "PONG", _args) do
    reply_update(state, Update.Pong)
  end

  def decode(state, "INFO", _args) do
    Lichat.Connection.write(state, encode_named(server(), "371", [server()], "Protocol #{Lichat.version()}, server #{Lichat.server_version()}"))
    Lichat.Connection.write(state, encode_named(server(), "374", [server()], "End of INFO list"))
    {:more, state}
  end

  def decode(state, "MOTD", _args) do
    Lichat.Connection.write(state, encode_named(server(), "375", [server()], "Start of MOTD"))
    Enum.each(String.split(Toolkit.banner(), "\n"), fn line ->
      Lichat.Connection.write(state, encode_named(server(), "372", [server()], line))
    end)
    Lichat.Connection.write(state, encode_named(server(), "376", [server()], "End of MOTD command"))
    {:more, state}
  end

  def decode(state, "NAMES", [chan | _]) do
    reply_update(state, Update.Users, [channel: from_channelname(chan)])
  end

  def decode(state, "MODE", [chan | _]) do
    Lichat.Connection.write(state, encode_named(server(), "324", [server(), chan, "+Cg"]))
    {:more, state}
  end

  def decode(state, "WHO", _args) do
    Lichat.Connection.write(state, encode_named(server(), "315", [server(), server()], "End of WHO list"))
    {:more, state}
  end

  def decode(state, command, args) do
    Logger.info("#{describe(state)} IRC: Ignoring unknown command #{command} #{Enum.join(args, " ")}")
    {:more, state}
  end

  def reply_update(state, type, args \\ []) do
    {:ok, Update.make(type, [{:id, Toolkit.id()} | [{:from, state.name} | args]]), state}
  end

  @impl Lichat.Connection
  def write(state, update) do
    case encode(state, update.type.__struct__, update) do
      :skip -> state
      string -> Lichat.Connection.write(state, string)
    end
  end

  def encode(state, Update.Connect, update) do
    Lichat.Connection.write(state, encode_named(Lichat.server_name(), "001", [update.from], "Welcome to the Lichat IRC gateway at #{server()}"))
    Lichat.Connection.write(state, encode_named(Lichat.server_name(), "002", [update.from], "Your host is #{:inet_parse.ntoa(state.ip)}"))
    Lichat.Connection.write(state, encode_named(Lichat.server_name(), "003", [update.from], "This server was created a while ago."))
    Lichat.Connection.write(state, encode_named(Lichat.server_name(), "004", [update.from, server(), Lichat.server_version(), "s", "Cg"]))
    Lichat.Connection.write(state, encode_named(Lichat.server_name(), "005", [update.from, "CHANTYPES=#", "CASEMAPPING=rfc1459", "CHANNELLEN=32", "NICKLEN=32", "NETWORK=#{server()}"]))
    Lichat.Connection.write(state, encode_named(Lichat.server_name(), "422", [update.from], "The motd is shown in the ##{server()} channel."))
    :skip
  end

  def encode(state, Update.Message, update) do
    if update.from != state.name or (Map.has_key?(update.type, :bridge) and is_binary(update.type.bridge)) do
      Enum.each(String.split(update.type.text, "\n"), fn line ->
        Lichat.Connection.write(state, encode_named(update.from, "PRIVMSG", [to_channelname(update.type.channel)], line))
      end)
    end
    :skip
  end

  def encode(_state, Update.Data, update) do
    encode_named(update.from, "PRIVMSG", [to_channelname(update.type.channel)], <<1::8, "ACTION Sent a file.", 1::8>>)
  end

  def encode(_state, Update.React, update) do
    encode_named(update.from, "PRIVMSG", [to_channelname(update.type.channel)], <<1::8, "ACTION Reacted with ", update.type.emote::binary, 1::8>>)
  end

  def encode(_state, Update.Edit, update) do
    encode_named(update.from, "PRIVMSG", [to_channelname(update.type.channel)], <<1::8, "ACTION Edited to: ", update.type.text::binary, 1::8>>)
  end

  def encode(state, Update.Join, update) do
    channel = to_channelname(update.type.channel)
    Lichat.Connection.write(state, encode_named(update.from, "JOIN", [channel]))
    if update.from == state.name do
      {:ok, channel_pid} = Channel.get(update.type.channel)
      users = Enum.map_join(Channel.usernames(channel_pid), " ", &to_source/1)
      topic = Channel.info(channel_pid, Symbol.kw("TOPIC"))
      Lichat.Connection.write(state, encode_named(Lichat.server_name(), "TOPIC", [server(), channel], topic))
      Lichat.Connection.write(state, encode_named(Lichat.server_name(), "353", [server(), "=", channel], users))
      Lichat.Connection.write(state, encode_named(Lichat.server_name(), "366", [server(), channel], "End of Names list"))
    end
    :skip
  end

  def encode(state, Update.Create, update) do
    encode(state, Update.Join, update)
  end

  def encode(_state, Update.Leave, update) do
    encode_named(update.from, "PART", [to_channelname(update.type.channel)])
  end

  def encode(_state, Update.Disconnect, update) do
    encode_named(update.from, "QUIT", [], "Quit: connection closed.")
  end

  def encode(_state, Update.SetChannelInfo, update) do
    if update.type.key == Symbol.kw("TOPIC") do
      encode_named(update.from, "TOPIC", [server(), to_channelname(update.type.channel)], update.type.text)
    else
      :skip
    end
  end

  def encode(state, Update.Users, update) do
    channel = to_channelname(update.type.channel)
    users = Enum.map_join(update.type.users, " ", &to_source/1)
    Lichat.Connection.write(state, encode_named(Lichat.server_name(), "353", ["=", channel], users))
    encode_named(Lichat.server_name(), "366", [server(), channel], "End of Names list")
  end

  def encode(_state, Update.Ping, update) do
    encode_named(update.from, "PING", [], server())
  end

  def encode(_state, Update.Pong, update) do
    encode_named(update.from, "PONG", [], server())
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
    encode_named(Lichat.server_name(), type, [update.from | parameters], update.type.text)
  end

  def encode_named(source, type, parameters, trail \\ nil) do
    {:ok, stream} = StringIO.open("")
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

  def to_safe_name(name) do
    String.replace(String.downcase(name), ["_", " ", ":"], fn <<char>> ->
      case char do
        ?_ -> "__"
        ?\s -> "_"
        ?: -> ".."
      end
    end)
  end

  def from_safe_name(name) do
    String.replace(name, ["__", "_", ".."], fn string ->
      case string do
        "__" -> "_"
        "_" -> " "
        ".." -> ":"
      end
    end)
  end

  def to_channelname(name) do
    "#" <> to_safe_name(name)
  end

  def to_source(name) do
    to_safe_name(name)
  end

  def from_channelname(<<?#, name::binary>>), do: from_safe_name(name)
  def from_channelname(name), do: from_safe_name(name)

  def from_source(name) do
    from_safe_name(name)
  end
  
  def server() do
    to_source(Lichat.server_name())
  end

  def strip_prefix(<<?:, rest::binary>>), do: rest
  def strip_prefix(rest), do: rest
  
  @impl Lichat.Connection
  def close(state) do
    write(state, Update.make(Update.Disconnect, [from: state.name]))
    Lichat.Connection.shutdown(state)
  end
end
