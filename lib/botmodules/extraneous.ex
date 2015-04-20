defmodule BotExtraneous do
  @behaviour BotModule
  @moduledoc "Reply to unknown triggers."

  def doc, do: @moduledoc

  def start do
  end

  def process_message(message) do
    if Regex.match? ~r/^!cah/, message.text do
      text = "We do not support that here. Sorry."
      Slack.send_message(message.channel, text)
    end
  end

  def stop(_reason) do
  end
end
