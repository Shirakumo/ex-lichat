defmodule Symbol do
  @enforce_keys [:name, :package]
  defstruct name: nil, package: nil

  def intern([package, name]) do
    intern(name, package)
  end
  
  def intern(name, package \\ :lichat) do
    %Symbol{name: name, package: package}
  end
end

defmodule WireFormat do
  import NimbleParsec

  defp not_quote(<<>>, context, _, _), do: {:halt, context}
  defp not_quote(<<c, _::binary>>, context, _, _) do
    if c in [0, ?"], do: {:halt, context}, else: {:cont, context}
  end
  defp not_paren(<<>>, context, _, _), do: {:halt, context}
  defp not_paren(<<c, _::binary>>, context, _, _) do
    if c in [0, ?\)], do: {:halt, context}, else: {:cont, context}
  end
  defp not_terminal(<<>>, context, _, _), do: {:halt, context}
  defp not_terminal(<<c, _::binary>>, context, _, _) do
    if c in [0, ?:, ?\s, ?", ?., ?(, ?)], do: {:halt, context}, else: {:cont, context}
  end

  # Probably could be done faster
  defp parse_int(list) do
    {i, _} = Integer.parse(to_string(list))
    i
  end

  defp parse_float(list) do
    {i, _} = Float.parse(to_string('0' ++ list ++ '0'))
    i
  end

  white = utf8_char([0x9, 0xA, 0xB, 0xC, 0xD, 0x20])
  
  any = utf8_char([not: 0x0])

  name_part = choice([
    ignore(string("\\")) |> concat(any),
    utf8_char([])
  ])
  name =
    name_part
    |> repeat_while(name_part, :not_terminal)
    |> reduce({List, :to_string, []})

  symbol_1 =
    name
    |> map({Symbol, :intern, [:lichat]})
  keyword =
    ignore(string(":"))
    |> concat(name)
    |> map({Symbol, :intern, [:keyword]})
  symbol_2 =
    name
    |> ignore(string(":"))
    |> concat(name)
    |> wrap()
    |> map({Symbol, :intern, []})
  
  symbol = choice([keyword, symbol_2, symbol_1])

  str_part = choice([
    ignore(string("\\")) |> concat(any),
    utf8_char([])
  ])
  str =
    ignore(string("\""))
    |> repeat_while(str_part, :not_quote)
    |> ignore(string("\""))
    |> reduce({List, :to_string, []})

  digit = ascii_char([?0, ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9])

  float_1 =
    digit
    |> repeat(digit)
    |> string(".")
    |> repeat(digit)
  float_2 =
    string(".")
    |> repeat(digit)
  float = 
    choice([float_1, float_2])
    |> reduce(:parse_float)
  integer =
    digit
    |> repeat(digit)
    |> reduce(:parse_int)
  number = choice([float, integer])
  
  list_part = parsec(:expr) |> ignore(repeat(white))
  list =
    ignore(string("("))
    |> ignore(repeat(white))
    |> repeat_while(list_part, :not_paren)
    |> ignore(string(")"))
    |> wrap()
    
  defparsec :expr, choice([str, list, number, symbol])

  object_part =
    keyword
    |> ignore(repeat(white))
    |> parsec(:expr)
    |> ignore(repeat(white))
  object =
    ignore(string("("))
    |> ignore(repeat(white))
    |> concat(symbol)
    |> repeat(object_part)
    |> ignore(string(")"))
    |> wrap()

  defparsec :update, choice([object, any]) |> ignore(optional(utf8_char([0x0])))
  
  def parse1(input) do
    case expr(input) do
      {:ok, [result], _, _, _, _} -> {:ok, result}
      _ -> {:error}
    end
  end
end
