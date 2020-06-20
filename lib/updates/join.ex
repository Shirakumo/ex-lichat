defmodule Update.Join do
  defstruct channel: nil
end

defimpl Update.Serialize, for: Update.Join do
  def type_symbol(_), do: %Symbol{name: "JOIN", package: :lichat}
  def to_list(type), do: [ :channel, type.channel ]
  def from_list(_, args) do
    Update.from_list(%Update{},
      [ :type, %Update.Join{
          channel: Toolkit.getf!(args, :channel)}
        | args ])
  end
end

defimpl Update.Execute, for: Update.Join do
  def handle(type, update, state) do
    case Channel.get(Channel, type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          nil # Connection.write(state, %AlreadyInChannel)
        else
          User.join(state.user, channel)
          Channel.write(channel, update)
        end
      :error ->
        nil # Connection.write(state, %NoSuchChannel)
    end
    state
  end
end
