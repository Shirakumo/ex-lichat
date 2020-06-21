defmodule Update do
  defstruct id: nil, clock: nil, from: nil, type: %{}

  ## Have to split here because protocols do not allow
  ## defimplementing only parts of it while falling back
  ## to defaults by Any on others, which sucks a lot.
  defprotocol Serialize do
    def type_symbol(update)
    def to_list(update)
    def from_list(update, args)
  end
  defprotocol Execute do
    def handle(type, update, connection)
  end

  defmacro __using__(_) do
    quote do
      import Update, only: [defupdate: 4]
    end
  end

  defmacro defupdate(name, symbol, fields, do: execute) do
    name = Module.concat(Update, Macro.expand(name, __ENV__))
    fields = Enum.map(fields, fn(x) ->
      case x do
        {field, symbol} -> {field, symbol}
        field -> {field, field}
      end
    end)
    fielddefs = Enum.map(fields, fn({x, _})->{x, nil} end)
    to_fields = Enum.flat_map(fields, fn({x, y})->[x, quote(do: Map.get(type, unquote(y)))] end)
    from_fields = Enum.map(fields, fn({x, y})->{x, quote(do: Toolkit.getf!(args, unquote(y)))} end)
    
    quote do
      defmodule unquote(name) do
        defstruct unquote(fielddefs)
        
        defimpl Update.Serialize, for: unquote(name) do
          def type_symbol(_), do: %Symbol{name: unquote(symbol), package: :lichat}
          def to_list(type), do: unquote(to_fields)
          def from_list(_, args) do
            Update.from_list(%Update{},
              [ :type, struct(unquote(name), unquote(from_fields)) | args ])
          end
        end
        
        defimpl Update.Execute, for: unquote(name) do
          unquote(execute)
        end
      end
    end
  end

  ## On the other hand, protocols also can't have other
  ## functions defined in them to use as helpers, so I guess
  ## now we can put parse/print in here again.
  def type_symbol(update), do: Serialize.type_symbol(update)
  def from_list(input, args), do: Serialize.from_list(input, args)
  def to_list(update), do: Serialize.to_list(update)

  ## This sucks lol
  @updates %{
    "PING" => Update.Ping,
    "PONG" => Update.Pong,
    "CONNECT" => Update.Connect,
    "DISCONNECT" => Update.Disconnect,
    "CREATE" => Update.Create,
    "JOIN" => Update.Join,
    "LEAVE" => Update.Leave,
    "MESSAGE" => Update.Message}
  
  # def list() do
  #   {:ok, mods} = :application.get_key(:lichat, :modules)
  #   mods
  #   |> Enum.filter(& &1 |> Module.has_attribute?(:update))
  #   |> Enum.map(&{String.upcase(List.last(Module.split(&1))), &1})
  # end

  def find_update(update_name) do
    @updates[update_name]
  end
  
  def from_list([type | args]) do
    if type.package == :lichat do
      case find_update(type.name) do
        nil -> raise "Unsupported update type #{type.name}"
        type -> Update.from_list(struct(type), args)
      end
    else
      raise "Unsupported update type #{type.name}"
    end
  end

  def parse(input) do
    case WireFormat.update1(input) do
      {:error, msg, _, _, _, _} -> raise msg
      {:ok, update} -> from_list(update)
    end
  end

  def print(update) do
    WireFormat.print1(to_list(update))
  end

  def handle(update, state) do
    Execute.handle(update.type, update, state)
  end

  def make(type, args) do
    id = Keyword.get_lazy(args, :id, &Toolkit.id/0)
    clock = Keyword.get_lazy(args, :clock, &Toolkit.universal_time/0)
    from = Keyword.fetch!(args, :from)
    type = struct(type, Keyword.drop(args, [:id, :clock, :from]))
    %Update{id: id, clock: clock, from: from, type: type}
  end

  def reply(update, type, args) do
    args = Keyword.put_new(args, :from, update.from)
    args = Keyword.put_new(args, :id, update.id)
    make(type, args)
  end
end

defimpl Update.Serialize, for: Any do
  def type_symbol(type) do
    Symbol.li(String.upcase(String.slice(Atom.to_string(type.__struct__), 15..-1)))
  end
  def to_list(_), do: []
  def from_list(type, args), do: Update.from_list(%Update{}, [ :type, type | args ])
end

defimpl Update.Serialize, for: Update do
  def type_symbol(_), do: %Symbol{name: "UPDATE", package: :lichat}
  def to_list(update) do
    [ Update.type_symbol(update.type),
      :id, update.id,
      :clock, update.clock,
      :from, update.from
      | Update.to_list(update.type) ]
  end
  def from_list(_, args) do
    %Update{
      id: Toolkit.getf!(args, :id),
      clock: Toolkit.getf!(args, :clock),
      from: Toolkit.getf!(args, :from),
      type: Toolkit.getf!(args, :type)}
  end
end
