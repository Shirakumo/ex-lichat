use Update
defmodule Update.Bridge do
  @behaviour Update
  @impl Update
  def type_symbol, do: %Symbol{name: "BRIDGE", package: :lichat}
  defstruct channel: nil

  defimpl Update.Serialize, for: Update.Bridge do
    def to_list(type), do: [channel: type.channel]
    def from_list(_, args) do
      Update.from_list(%Update{},
        [:type, %Update.Bridge{channel: Update.getf!(args, "CHANNEL")}])
    end
  end

  defimpl Update.Execute, for: Update.Bridge do
    def handle(type, update, state) do
      case Channel.get(type.channel) do
        {:ok, _channel} ->
          Lichat.Connection.write(state, update)
        :error ->
          Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel))
      end
      state
    end
  end

  def bridge(type, update, state, channel) do
    if Channel.permitted?(channel, Update.Bridge, update.from) do
      Channel.write(channel, %{update | from: type.bridge, type: %{type | bridge: update.from}})
    else
      Lichat.Connection.write(state, Update.fail(update, Update.InsufficientPermissions))
    end
    state
  end
end
