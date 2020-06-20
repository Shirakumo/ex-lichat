defmodule Update.Leave do
  defstruct channel: nil
end

defimpl Update.Serialize, for: Update.Leave do
  def type_symbol(_), do: %Symbol{name: "LEAVE", package: :lichat}
  def to_list(type), do: [ :channel, type.channel ]
  def from_list(_, args) do
    Update.from_list(%Update{},
      [ :type, %Update.Leave{
          channel: Toolkit.getf!(args, :channel)}
        | args ])
  end
end

defimpl Update.Execute, for: Update.Leave do
  def handle(type, update, state) do
    case Channel.get(Channel, type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          Channel.write(channel, update)
          User.leave(state.user, channel)
        else
          nil # Connection.write(state, %NotInChannel)
        end
      :error ->
        nil # Connection.write(state, %NoSuchChannel)
    end
    state
  end
end
