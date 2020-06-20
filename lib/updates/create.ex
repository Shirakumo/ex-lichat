defmodule Update.Create do
  defstruct channel: nil
end

defimpl Update.Serialize, for: Update.Create do
  def type_symbol(_), do: %Symbol{name: "CREATE", package: :lichat}
  def to_list(type), do: [ :channel, type.channel ]
  def from_list(_, args) do
    Update.from_list(%Update{},
      [ :type, %Update.Create{
          channel: Toolkit.getf!(args, :channel)}
        | args ])
  end
end

defimpl Update.Execute, for: Update.Create do
  def handle(type, update, state) do
    case Channel.get(Channel, type.channel) do
      {:ok, channel} ->
        nil # Connection.write(state, %ChannelExists)
      :error ->
        channel = Channel.ensure_channel(Channel, type.channel)
        User.join(state.user, channel)
        Connection.write(state, Update.reply(update, Update.Join, [channel: type.channel]))
    end
    state
  end
end
