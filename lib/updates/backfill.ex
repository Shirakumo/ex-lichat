use Update
defupdate(Backfill, "BACKFILL", [:channel]) do
  def handle(type, update, state) do
    case Channel.get(type.channel) do
      {:ok, channel} ->
        if User.in_channel?(state.user, channel) do
          data = Channel.data(channel)
          {_name, _ref, since} = Map.fetch!(data.users, state.user)
          Backlog.each(data.backlog, fn old ->
            if old.clock < since do
              false
            else
              if old.from != update.from or old.type.__struct__ != Update.Join do
                Connection.write(state, old)
              end
              true
            end
          end)
        else
          Connection.write(state, Update.fail(update, Update.NotInChannel))
        end
      :error ->
        Connection.write(state, Update.fail(update, Update.NoSuchChannel))
    end
    state
  end
end
