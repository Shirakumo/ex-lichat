defmodule Error do
  defmodule ParseFailure, do: defexception message: "Parse failed"
  defmodule UnsupportedUpdate do
    defexception symbol: nil, message: "Unsupported update"

    @impl true
    def exception(symbol) do
      msg = "Unsupported update type: #{inspect(symbol)}"
      %UnsupportedUpdate{symbol: symbol, message: msg}
    end
  end
end
