defmodule Rtm do
  @url "https://slack.com/api/rtm.start"

  def start(token) do
    url = @url <> token
  end
end
