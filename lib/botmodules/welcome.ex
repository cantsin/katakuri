defmodule BotWelcome do
  @behaviour BotModule
  @moduledoc "Emit a greeting when we first join Slack."

  def start() do
    # TODO find main channel
    channel = List.first Slack.get_channels()
    Slack.send_message(channel.id, "Greetings.")
  end

  def process(_message) do

  end

  def stop(_reason) do

  end
end
