defmodule Katakuri do
  def init(token) do
    modules = [BotWelcome]
    {:ok, result} = Rtm.start(token)
    :websocket_client.start_link(result[:url], Client, [result, modules])
  end
end
