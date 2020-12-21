defmodule Version do
  def get, do: "2.0"

  def compatible_versions, do: [ "2.0", "1.5", "1.4", "1.3", "1.2", "1.1", "1.0" ]

  def extensions, do: ["shirakumo-data"]
  
  def compatible?(version) do
    Enum.member?(compatible_versions(), version)
  end
end
