defmodule Update.Ping do
  @derive [Update.Serialize]
  defstruct _: nil
end

defimpl Update.Execute, for: Update.Ping do
  def handle(_type, update, state) do
    Connection.write(state, Update.reply(update, Update.Pong, []))
    state
  end
end
