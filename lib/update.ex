defmodule Update do
  defstruct id: nil, clock: nil, from: nil, type: %{}

  defmodule Ping do defstruct _: nil end
  defmodule Pong do defstruct _: nil end
  defmodule Connect do defstruct password: nil, version: nil, extensions: [] end
  defmodule Disconnect do defstruct _: nil end
  defmodule Join do defstruct channel: nil end
  defmodule Leave do defstruct channel: nil end
  defmodule Message do defstruct channel: nil, text: nil end

  def make(from, type) do
    %Update{
      id: Toolkit.id(),
      clock: Toolkit.universal_time(),
      from: from,
      type: type
    }
  end
end
