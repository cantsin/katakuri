defmodule BotWelcome do
  @behaviour BotModule
  @moduledoc "Emit a greeting when we first join Slack."
  @greetings ["السلام عليكم", "你好", "Hallo", "Bonjour", "Γειά σας", "नमस्ते", "שלום", "今日は", "안녕하세요", "Cześć", "Olá", "Здравствуйте", "Hola", "Chào anh"]

  def start() do
    channel = Slack.get_general_channel()
    message = "I am your friendly bot, " <> (@greetings |> Enum.shuffle |> List.first) <> "!"
    Slack.send_message(channel.id, message)
  end

  def process(_message) do

  end

  def stop(_reason) do
    channel = Slack.get_general_channel()
    message = "I'll be back..."
    Slack.send_message(channel.id, message)
  end
end
