defmodule Update.Pong do
  @derive [Update.Serialize]
  defstruct _: nil
end

defimpl Update.Execute, for: Update.Pong do
  def handle(_type, _update, state) do
    state
  end
end
