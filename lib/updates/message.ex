defmodule Update.Message do
  defstruct channel: nil, text: nil
end

defimpl Update.Serialize, for: Update.Message do
  def type_symbol(_), do: %Symbol{name: "MESSAGE", package: :lichat}
  def to_list(type), do: [ :channel, type.channel, :text, type.text ]
  def from_list(_, args) do
    Update.from_list(%Update{},
      [ :type, %Update.Message{
          channel: Toolkit.getf!(args, :channel),
          text: Toolkit.getf!(args, :text)}
        | args ])
  end
end

defimpl Update.Execute, for: Update.Message do
  def handle(type, update, state) do
    case Channel.get(Channel, type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          Channel.write(channel, update)
        else
          nil # Connection.write(state, %NotInChannel)
        end
      :error ->
        nil # Connection.write(state, %NoSuchChannel)
    end
    state
  end
end
