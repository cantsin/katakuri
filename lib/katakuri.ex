defmodule Katakuri do
  def init(token) do
    {:ok, url} = Rtm.start(token)
    :websocket_client.start_link(url, Client, {})
  end
end
