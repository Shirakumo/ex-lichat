defmodule Connection do
  use Task
  require Logger
  defstruct socket: nil, user: nil, name: nil, state: nil, accumulator: <<>>

  def start_link(socket) do
    :inet.setopts(socket, [active: true])
    Task.start_link(__MODULE__, :run, [%Connection{socket: socket}])
  end
  
  def run(state) do
    next_state =
      receive do
      {:tcp, socket, data} ->
        state = %{state | socket: socket}
        case stitch(state, data, Toolkit.config(:max_update_size, 8192)) do
          {:ok, update, state} ->
            handle_update(state, update)
          {:more, state} ->
            state
        end
      {:tcp_closed, _} ->
        Logger.info("TCP closed #{inspect(state.user)}")
        %{state | state: :closed}
      {:tcp_error, _} ->
        Logger.info("TCP error #{inspect(state.user)}")
        %{state | state: :closed}
      {:send, msg} ->
        write(state, msg)
    end
    run(next_state)
  end

  def stitch(state, data, max_size) do
    case state.accumulator do
      :dropping ->
        case :binary.split(data, <<0>>) do
          [ _, rest ] ->
            stitch(%{state | accumulator: <<>>}, rest, max_size)
          _ ->
            {:more, state}
        end
      acc ->
        data = acc <> data
        case :erlang.decode_packet(:line, data, [line_length: max_size]) do
          {:ok, payload, rest} ->
            if :binary.last(payload) != 0 and byte_size(payload) == max_size do
              write(state, Update.fail(Update.UpdateTooLong))
              stitch(%{state | accumulator: :dropping}, rest, max_size)
            else
              {:ok, payload, %{state | accumulator: rest}}
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

  def handle_update(state, data) do
    try do
      update = Update.parse(data)
      try do
        case state.state do
          nil ->
            if update.type.__struct__ == Update.Connect do
              Update.handle(update, state)
            else
              write(state, Update.fail(Update.InvalidUpdate))
              close(state)
            end
          :closed ->
            close(state)
          _ ->
            update = case update.from do
                       nil -> %{update | from: state.name}
                       _ -> update
                     end
            cond do
              update.from != state.name ->
                write(state, Update.fail(update, Update.UsernameMismatch))
              not Update.permitted?(update) ->
                write(state, Update.fail(update, Update.InsufficientPermissions))
              true ->
                Update.handle(update, state)
            end
        end
      rescue
        e in RuntimeError ->
          write(state, Update.fail(update, Update.UpdateFailure, [text: e.message]))
      end
    rescue
      e in Error.ParseFailure ->
        write(state, Update.fail(Update.MalformedUpdate, e.message))
      e in Error.UnsupportedUpdate ->
        write(state, Update.fail(Update.InvalidUpdate, e.message))
      e in RuntimeError ->
        write(state, Update.fail(Update.Failure, e.message))
    end
  end

  def write(state, update) do
    :gen_tcp.send(state.socket, Update.print(update))
    state
  end
  
  def establish(state, update) do
    Logger.info("Connect #{inspect(update)}")
    user = User.connect(User.ensure_user(User, update.from), self())
    write(state, Update.reply(update, Update.Connect, [
              version: Lichat.version(),
              extensions: Lichat.extensions()]))
    Enum.each(User.channels(user), fn {channel, _} ->
      write(state, Update.make(Update.Join, [
                from: update.from,
                channel: Channel.name(channel) ])) end)
    %{state | state: :connected, user: user, name: update.from}
  end

  def close(state) do
    write(state, Update.make(Update.Disconnect, [
              from: Toolkit.config(:name)
            ]))
    :gen_tcp.shutdown(state.socket, :write)
    %{state | state: :closed}
  end
end
