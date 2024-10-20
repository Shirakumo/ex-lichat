defmodule Update do
  require Logger
  defstruct id: nil, clock: nil, from: nil, type: %{}
  @callback type_symbol() :: Symbol.t
  
  ## Have to split here because protocols do not allow
  ## defimplementing only parts of it while falling back
  ## to defaults by Any on others, which sucks a lot.
  defprotocol Serialize do
    def to_list(update)
    def from_list(update, args)
  end
  defprotocol Execute do
    def handle(type, update, connection)
  end

  defmacro __using__(_) do
    quote do
      import Update, only: [defupdate: 3, defupdate: 4]
    end
  end

  defmacro defupdate(name, symbol, fields) do
    quote do defupdate(unquote(name), unquote(symbol), unquote(fields)) do
            def handle(_, _, state), do: state
      end end
  end

  defmacro defupdate(name, symbol, fields, do: execute) do
    name = Module.concat(Update, Macro.expand(name, __ENV__))
    fields = Enum.map(fields, fn(x) ->
      case x do
        [field | args] -> {field, Keyword.get(args, :symbol, String.upcase(Atom.to_string(field))), Keyword.get(args, :default), Keyword.get(args, :required)}
        field -> {field, String.upcase(Atom.to_string(field)), nil, true}
      end
    end)
    fielddefs = Enum.map(fields, fn({x, _, d, _})->
      {x, d}
    end)
    to_fields = Enum.flat_map(fields, fn({x, y, _, _})->
      [quote(do: Symbol.kw(unquote(y))), quote(do: Map.get(type, unquote(x)))]
    end)
    from_fields = Enum.map(fields, fn({x, y, _, r})->
      {x, if r do
            quote(do: Update.getf!(args, unquote(y)))
          else
            quote(do: Toolkit.getf(args, unquote(y)))
          end}
    end)
    
    quote do
      defmodule unquote(name) do
        Module.register_attribute(unquote(name), :is_update?, persist: true)
        @is_update? true
        
        @behaviour Update
        @impl Update
        def type_symbol, do: %Symbol{name: unquote(symbol), package: :lichat}
        
        defstruct unquote(fielddefs)
        
        defimpl Update.Serialize, for: unquote(name) do
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
  def type_symbol(update), do: update.__struct__.type_symbol()
  def from_list(input, args), do: Serialize.from_list(input, args)
  def to_list(update), do: Serialize.to_list(update)

  def find_type(update_name) do
    ## TODO: cache list_types
    Enum.find(list_types(), &(&1.type_symbol() == update_name))
  end

  def ensure_type(type) when is_atom(type), do: type
  def ensure_type(type) when is_struct(type), do: find_type(type)
  def ensure_type(type) when is_binary(type), do: find_type(Symbol.li(type))
  
  def from_list([symbol | args]) do
    if symbol.package == :lichat do
      case find_type(symbol) do
        nil -> raise Error.UnsupportedUpdate, symbol
        type -> Update.from_list(struct(type), args)
      end
    else
      raise Error.UnsupportedUpdate, symbol
    end
  end

  def parse(input) when is_binary(input) do
    case WireFormat.update1(input) do
      {:error, msg, _, _, _, idx} -> raise Error.ParseFailure, message: "Error at position #{idx}: #{msg}, original message: #{input}"
      {:ok, update} -> from_list(update)
    end
  end

  def parse(%Update{} = input) do
    input
  end

  def print(update) do
    WireFormat.print1(to_list(update))
  end

  def handle(update, state) do
    Execute.handle(update.type, update, state)
  end

  def permitted?(update) do
    case Map.get(update.type, :channel) do
      nil ->
        Channel.permitted?(Channel.primary(), update)
      channel ->
        cond do
          channel == false or channel == "" ->
            :error
          update.type.__struct__ == Update.Create ->
            parent = Toolkit.parent_name(channel)
            if parent == nil do
              Channel.permitted?(Channel.primary(), update)
            else
              case Channel.permitted?(parent, update) do
                true -> true
                :no_such_channel -> :no_such_parent
              end
            end
          true ->
            Channel.permitted?(channel, update)
        end
    end
  end

  def make(type, args) do
    id = Keyword.get_lazy(args, :id, &Toolkit.id/0)
    clock = Keyword.get_lazy(args, :clock, &Toolkit.universal_time/0)
    from = Keyword.get_lazy(args, :from, &Lichat.server_name/0)
    type = struct(type, Keyword.drop(args, [:id, :clock, :from]))
    %Update{id: id, clock: clock, from: from, type: type}
  end

  def reply(update, type, args) do
    args = Keyword.put_new(args, :from, update.from)
    args = Keyword.put_new(args, :id, update.id)
    make(type, args)
  end

  def fail(type) do
    make(type, [from: Lichat.server_name()])
  end

  def fail(update, type) when is_struct(update) do
    make(type, [update_id: update.id])
  end

  def fail(type, message) when is_binary(message) do
    make(type, [from: Lichat.server_name(), text: message])
  end

  def fail(type, args) do
    make(type, [from: Lichat.server_name()] ++ args)
  end
  
  def fail(update, type, message) when is_struct(update) and is_binary(message) do
    make(type, [update_id: update.id, from: Lichat.server_name(), text: message])
  end

  def fail(update, type, args) when is_struct(update) do
    make(type, [update_id: update.id, from: Lichat.server_name()] ++ args)
  end

  def is_update?(module) do
    is_atom(module)
    and module != nil
    and case Keyword.get(module.__info__(:attributes), :is_update?) do
      [x] -> x
      nil -> false
    end
  end

  def list_types() do
    {:ok, mods} = :application.get_key(:lichat, :modules)
    Enum.filter(mods, &is_update?(&1))
  end

  def getf!(plist, key) do
    case Toolkit.getf(plist, key) do
      nil -> raise Error.ParseFailure, message: "Key #{key} is missing."
      x -> x
    end
  end
end

defimpl Update.Serialize, for: Any do
  def type_symbol(type) do
    Symbol.li(String.upcase(String.slice(Atom.to_string(type.__struct__), 15..-1//1)))
  end
  def to_list(_), do: []
  def from_list(type, args), do: Update.from_list(%Update{}, [ :type, type | args ])
end

defimpl Update.Serialize, for: Update do
  def type_symbol(_), do: %Symbol{name: "UPDATE", package: :lichat}
  def to_list(update) do
    [ Update.type_symbol(update.type) |
      Toolkit.prune_plist([
        :id, update.id,
        :clock, update.clock,
        :from, update.from
        | Update.to_list(update.type) ])]
  end
  def from_list(_, args) do
    %Update{
      id: Update.getf!(args, "ID"),
      clock: Toolkit.getf(args, "CLOCK", Toolkit.universal_time()),
      from: Toolkit.getf(args, "FROM"),
      type: Update.getf!(args, :type)}
  end
end
