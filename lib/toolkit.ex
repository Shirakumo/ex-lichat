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
end
