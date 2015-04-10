defmodule Katakuri do
  @modules [BotWelcome]

  def init(token) do
    {:ok, result} = Rtm.start(token)
    :websocket_client.start_link(result[:url], Client, [result, @modules])
  end
end
