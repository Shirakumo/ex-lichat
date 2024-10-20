defmodule Symbol do
  @enforce_keys [:name, :package]
  defstruct name: nil, package: nil

  def intern([package, name]) do
    intern(name, package)
  end
  
  def intern(name, package \\ :lichat) do
    %Symbol{name: name, package: package}
  end

  def kw(name) do
    %Symbol{name: name, package: :keyword}
  end

  def li(name) do
    %Symbol{name: name, package: :lichat}
  end

  def is_symbol(thing) do
    is_struct(thing) && thing.__struct__ == Symbol
  end
end

defmodule WireFormat do
  defmodule Reader do
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
      {i, _} = Float.parse(to_string(~c"0" ++ list ++ ~c"0"))
      i
    end

    defp parse_symbol("T"), do: true
    defp parse_symbol("NIL"), do: nil
    defp parse_symbol(name), do: Symbol.li(name)

    defp upcase_char(c) do
      <<c>> = String.upcase(<<c>>)
      c
    end

    white = utf8_char([0x9, 0xA, 0xB, 0xC, 0xD, 0x20])
    
    any = utf8_char([not: 0x0])

    name_part = choice([
      ignore(string("\\")) |> concat(any),
      utf8_char([not: 0, not: ?:, not: ?\s, not: ?", not: ?., not: ?(, not: ?)]) |> map(:upcase_char)
    ])
    name =
      name_part
      |> repeat_while(name_part, :not_terminal)
      |> reduce({List, :to_string, []})

    symbol_1 =
      name
      |> map(:parse_symbol)
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
      symbol
      |> ignore(repeat(white))
      |> parsec(:expr)
      |> ignore(repeat(white))
    object =
      ignore(repeat(white))
      |> ignore(string("("))
      |> ignore(repeat(white))
      |> concat(symbol)
      |> ignore(repeat(white))
      |> repeat(object_part)
      |> ignore(string(")"))
      |> wrap()

    defparsec :update, object |> ignore(optional(utf8_char([0x0])))
  end

  defmodule Printer do
    def string_(_, <<>>) do end
    
    def string_(stream, <<c, rest::binary>>) do
      case c do
        ?" -> IO.write(stream, "\\")
        ?\\-> IO.write(stream, "\\")
        x -> x
      end
      IO.binwrite(stream, <<c>>)
      string_(stream, rest)
    end

    def list_(_, []) do end
    def list_(stream, [a]) do
      print(stream, a)
    end
    def list_(stream, [a, b]) do
      print(stream, a)
      IO.write(stream, " ")
      print(stream, b)
    end
    def list_(stream, [a, b | c]) do
      print(stream, a)
      IO.write(stream, " ")
      list_(stream, [b|c])
    end

    def name_(_, <<>>) do end
    def name_(stream, <<c, rest::binary>>) do
      if <<c>> != String.upcase(<<c>>) do
        IO.write(stream, <<?\\, c>>)
      else
        IO.write(stream, String.downcase(<<c>>))
      end
      name_(stream, rest)
    end

    def print(stream, symbol) when is_struct(symbol) do
      case symbol.package do
        :keyword ->
          IO.write(stream, ":")
        :lichat ->
          nil
        package ->
          name_(stream, package)
          IO.write(stream, ":")
      end
      name_(stream, symbol.name)
    end

    def print(stream, string) when is_binary(string) do
      IO.write(stream, "\"")
      string_(stream, string)
      IO.write(stream, "\"")
    end

    def print(stream, number) when is_float(number) do
      IO.write(stream, Float.to_string(number))
    end

    def print(stream, number) when is_integer(number) do
      IO.write(stream, Integer.to_string(number))
    end

    def print(stream, list) when is_list(list) do
      IO.write(stream, "(")
      list_(stream, list)
      IO.write(stream, ")")
    end

    def print(stream, nil) do
      IO.write(stream, "NIL")
    end

    def print(stream, false) do
      IO.write(stream, "NIL")
    end

    def print(stream, true) do
      IO.write(stream, "T")
    end

    def print(stream, atom) do
      IO.write(stream, ":")
      IO.write(stream, Atom.to_string(atom))
    end
  end
  
  def parse1(input) do
    case Reader.expr(input) do
      {:ok, [result], _, _, _, _} -> {:ok, result}
      x -> x
    end
  end

  def update1(input) do
    case Reader.update(input) do
      {:ok, [result], _, _, _, _} -> {:ok, result}
      x -> x
    end
  end

  def print1(input) do
    {:ok, stream} = StringIO.open("",[encoding: :latin1])
    Printer.print(stream, input)
    IO.write(stream, <<10, 0>>)
    {:ok, {_, result}} = StringIO.close(stream)
    result
  end
end
