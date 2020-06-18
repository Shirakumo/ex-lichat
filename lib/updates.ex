defmodule Updates do
  require Logger
  defmodule Ping do
    @derive [Update.Serialize]
    defstruct _: nil
  end
  
  defmodule Pong do
    @derive [Update.Serialize]
    defstruct _: nil
  end

  defmodule Connect do
    defstruct password: nil, version: nil, extensions: []
  end
  defimpl Update.Serialize, for: Connect do
    def type_symbol(_), do: %Symbol{name: "CONNECT", package: :lichat}
    def to_list(type) do
      [ :password, type.password,
        :version, type.version,
        :extensions, type.extensions ]
    end
    def from_list(_, args) do
      Update.from_list(%Update{},
        [ :type, %Connect{
            password: Toolkit.getf(args, :password),
            version: Toolkit.getf!(args, :version),
            extensions: Toolkit.getf(args, :extensions)}
          | args ])
    end
  end
  
  defmodule Disconnect do
    @derive [Update.Serialize]
    defstruct _: nil
  end
  
  defmodule Join do
    defstruct channel: nil
  end
  defimpl Update.Serialize, for: Join do
    def type_symbol(_), do: %Symbol{name: "JOIN", package: :lichat}
    def to_list(type), do: [ :channel, type.channel ]
    def from_list(_, args) do
      Update.from_list(%Update{},
        [ :type, %Join{
            channel: Toolkit.getf!(args, :channel)}
          | args ])
    end
  end
  
  defmodule Leave do
    defstruct channel: nil
  end
  defimpl Update.Serialize, for: Leave do
    def type_symbol(_), do: %Symbol{name: "LEAVE", package: :lichat}
    def to_list(type), do: [ :channel, type.channel ]
    def from_list(_, args) do
      Update.from_list(%Update{},
        [ :type, %Leave{
            channel: Toolkit.getf!(args, :channel)}
          | args ])
    end
  end
  
  defmodule Message do
    defstruct channel: nil, text: nil
  end
  defimpl Update.Serialize, for: Message do
    def type_symbol(_), do: %Symbol{name: "MESSAGE", package: :lichat}
    def to_list(type), do: [ :channel, type.channel, :text, type.text ]
    def from_list(_, args) do
      Update.from_list(%Update{},
        [ :type, %Message{
            channel: Toolkit.getf!(args, :channel),
            text: Toolkit.getf!(args, :text)}
          | args ])
    end
  end

  ## This sucks lol
  @updates %{
    "PING" => Updates.Ping,
    "PONG" => Updates.Pong,
    "CONNECT" => Updates.Connect,
    "DISCONNECT" => Updates.Disconnect,
    "JOIN" => Updates.Join,
    "LEAVE" => Updates.Leave,
    "MESSAGE" => Updates.Message}
  
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
end
