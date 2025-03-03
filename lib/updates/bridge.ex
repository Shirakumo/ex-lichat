use Update
defmodule Update.Bridge do
  require Logger
  @behaviour Update
  @impl Update

  Module.register_attribute(Update.Bridge, :is_update?, persist: true)
  @is_update? true

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
          IpLog.record(state, Update.Bridge, type.channel)
          Lichat.Connection.write(state, update)
        :error ->
          Failure.no_such_channel(state, update)
      end
      state
    end
  end

  def bridge(type, update, state, channel) do
    if Channel.permitted?(channel, Update.Bridge, update.from) do
      Channel.write(channel, %{update | from: type.bridge, type: %{type | bridge: update.from}})
    else
      Logger.info("#{update.from} attempted to bridge #{inspect(update)} in #{type.channel} and has been denied.", [intent: :user])
      Lichat.Connection.write(state, Update.fail(update, Update.InsufficientPermissions))
    end
    state
  end
end
