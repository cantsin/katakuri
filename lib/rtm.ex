defmodule Rtm do
  @url "https://slack.com/api/rtm.start?token="

  def start(token) do
    HTTPotion.start
    response = HTTPotion.get(@url <> token)
    result = response.body |> to_string |> :jsx.decode |> JSONMap.to_map
    %{ok: validated} = result
    if validated do
      {:ok, result}
    else
      {:error, "Token is incorrect."}
    end
  end
end
