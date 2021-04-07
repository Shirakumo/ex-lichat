defmodule Init do
  require Logger
  def start_link(_opts) do
    Channels.reload()
    Channel.ensure_channel()
    User.ensure_user()
    :ignore
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary
    }
  end
end
