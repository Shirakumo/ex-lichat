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
    case type.channel do
      nil ->
        {name, channel} = Channel.make(Channel)
        User.join(state.user, channel)
        Connection.write(state, Update.reply(update, Update.Join, [channel: name]))
      name ->
        case Channel.ensure_channel(Channel, name) do
          {:old, _} ->
            nil # Connection.write(state, %ChannelExists)
          {:new, channel} ->
            User.join(state.user, channel)
            Connection.write(state, Update.reply(update, Update.Join, [channel: name]))
        end
    end
    state
  end
end
