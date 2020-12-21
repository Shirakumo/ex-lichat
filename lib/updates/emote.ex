use Update
defupdate(Emote, "EMOTE", [[:content_type, symbol: "CONTENT-TYPE"], :payload, :name]) do
  def handle(_type, _update, state) do
    state
  end
end

