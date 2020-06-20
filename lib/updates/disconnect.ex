defmodule Update.Disconnect do
  @derive [Update.Serialize]
  defstruct _: nil
end

defimpl Update.Execute, for: Update.Disconnect do
  def handle(_type, _update, connection) do
    Connection.close(connection)
  end
end
