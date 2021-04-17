use Update
defupdate(Data, "DATA", [:channel, [:content_type, symbol: "CONTENT-TYPE"], :filename, :payload]) do
  def handle(type, update, state) do
    if is_list(Toolkit.config(:allowed_content_types))
    and not Enum.member?(Toolkit.config(:allowed_content_types), type.content_type) do
      Lichat.Connection.write(state, Update.fail(update, Update.BadContentType, [
                allowed_content_types: Toolkit.config(:allowed_content_types) ]))
    else
      case Channel.get(type.channel) do
        {:ok, channel} ->
          if User.in_channel?(state.user, channel) do
            # FIXME: Distribute link only to users that support the extension over data.
            if Channel.permitted?(channel, Update.Link, update.from) do
              url = Update.Link.save(update.channel, type.content_type, type.payload)
              link = %{update | type: %{type | __struct__: Update.Link, payload: url}}
              Channel.write(channel, link)
            else
              Channel.write(channel, update)
            end
          else
            Lichat.Connection.write(state, Update.fail(update, Update.NotInChannel))
          end
        :error ->
          Lichat.Connection.write(state, Update.fail(update, Update.NoSuchChannel))
      end
    end
    state
  end
end
