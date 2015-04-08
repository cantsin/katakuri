defmodule Rtm do
  @url "https://slack.com/api/rtm.start?token="

  def start(token) do
    HTTPotion.start
    response = HTTPotion.get (@url <> token)
    response.body |> to_string |> :jsx.decode |> JSONMap.to_map
  end
end
