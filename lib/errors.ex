defmodule Error do
  defmodule ParseFailure, do: defexception message: "Parse failed"
  defmodule UnsupportedUpdate, do: defexception symbol: nil
end
