defmodule Katakuri do
  def init(token) do
    {:ok, result} = Rtm.start(token)
    :websocket_client.start_link(result[:url], Client, result)
  end
end
