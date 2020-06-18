defmodule Update do
  defstruct id: nil, clock: nil, from: nil, type: %{}

  defmodule Ping do defstruct _: nil end
  defmodule Pong do defstruct _: nil end
  defmodule Connect do defstruct password: nil, version: nil, extensions: [] end
  defmodule Disconnect do defstruct _: nil end
  defmodule Join do defstruct channel: nil end
  defmodule Leave do defstruct channel: nil end
  defmodule Message do defstruct channel: nil, text: nil end

  def type_symbol(update) do
    Symbol.li(String.slice(Atom.to_string(update.type.__struct__), 7..-1))
  end

  def make(from, type) do
    %Update{
      id: Toolkit.id(),
      clock: Toolkit.universal_time(),
      from: from,
      type: type
    }
  end

  ## This sucks lol
  def from_list(%Update{}, args) do
    %Update{
      id: Toolkit.getf!(args, :id),
      clock: Toolkit.getf!(args, :clock),
      from: Toolkit.getf!(args, :from),
      type: Toolkit.getf!(args, :type)}
  end

  def from_list(%Connect{}, args) do
    from_list(%Update{}, [ :type, %Connect{
                             password: Toolkit.getf(args, :password),
                             version: Toolkit.getf!(args, :version),
                             extensions: Toolkit.getf(args, :extensions)}
                           | args ])
  end

  def from_list(%Join{}, args) do
    from_list(%Update{}, [ :type, %Join{
                             channel: Toolkit.getf!(args, :channel)}
                           | args ])
  end
  
  def from_list(%Leave{}, args) do
    from_list(%Update{}, [ :type, %Leave{
                             channel: Toolkit.getf!(args, :channel)}
                           | args ])
  end
  
  def from_list(%Message{}, args) do
    from_list(%Update{}, [ :type, %Message{
                             channel: Toolkit.getf!(args, :channel),
                             text: Toolkit.getf!(args, :text)}
                           | args ])
  end
  
  def from_list(type, args) do
    from_list(%Update{}, [ :type, type | args ])
  end

  def from_list([type | args]) do
    cond do
      type == Symbol.li("PING") ->
        from_list(%Ping{}, args)
      type == Symbol.li("PONG") ->
        from_list(%Pong{}, args)
      type == Symbol.li("CONNECT") ->
        from_list(%Connect{}, args)
      type == Symbol.li("DISCONNECT") ->
        from_list(%Disconnect{}, args)
      type == Symbol.li("JOIN") ->
        from_list(%Join{}, args)
      type == Symbol.li("LEAVE") ->
        from_list(%Leave{}, args)
      type == Symbol.li("MESSAGE") ->
        from_list(%Message{}, args)
      true -> raise "Unsupported update type #{type}"
    end
  end

  def from_list({:ok, list}), do: from_list(list)
  def from_list(x), do: x

  defprotocol Listable do
    def to_list(thing)
  end
  defimpl Listable, for: Update do
    def to_list(update) do
      [ Update.type_symbol(update),
        :id, update.id,
        :clock, update.clock,
        :from, update.from
        | Listable.to_list(update.type) ]
    end
  end
  defimpl Listable, for: Ping do
    def to_list(_), do: []
  end
  defimpl Listable, for: Pong do
    def to_list(_), do: []
  end
  defimpl Listable, for: Connect do
    def to_list(type) do
      [ :password, type.password,
        :version, type.version,
        :extensions, type.extensions ]
    end
  end
  defimpl Listable, for: Disconnect do
    def to_list(_), do: [] 
  end
  defimpl Listable, for: Join do
    def to_list(type), do: [ :channel, type.channel ] 
  end
  defimpl Listable, for: Leave do
    def to_list(type), do: [ :channel, type.channel ] 
  end
  defimpl Listable, for: Message do
    def to_list(type), do: [ :channel, type.channel, :text, type.text ] 
  end  

  def parse(input) when is_binary(input) do
    case WireFormat.update1(input) do
      {:error, msg, _, _, _, _} -> raise msg
      x -> from_list(x)
    end
  end

  def print(update) do
    WireFormat.print1(Listable.to_list(update))
  end
end
