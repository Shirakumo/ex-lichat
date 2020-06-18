defmodule Toolkit do
  def init() do
    :ets.new(__MODULE__, [:public, :named_table])
  end
  
  def id() do
    :ets.update_counter(__MODULE__, :lichatID, 1, {1, 0})
  end
  
  def universal_time() do
    System.system_time(:second) + 2208985200
  end

  def getf!(plist, key) do
    case getf(plist, key) do
      nil -> raise "Key #{key} is missing."
      x -> x
    end
  end

  def getf(plist, key, default \\ nil)
  def getf([], _key, default), do: default
  def getf([ k, v | c ], key, default) when is_atom(k) do
    if k == key, do: v, else: getf(c, key, default)
  end
  def getf([ k, v | c ], key, default) when is_struct(k) do
    if String.upcase(Atom.to_string(key)) == k.name, do: v, else: getf(c, key, default)
  end
end
