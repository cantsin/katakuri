defmodule BotWelcome do
  @behaviour BotModule
  @moduledoc "Emit a greeting when we first join Slack. Also supports !help"
  @greetings ["السلام عليكم", "你好", "Hallo", "Bonjour", "Γειά σας", "नमस्ते", "שלום", "今日は", "안녕하세요", "Cześć", "Olá", "Здравствуйте", "Hola", "Chào anh"]

  def doc, do: @moduledoc

  def start() do
    channel = Slack.get_general_channel()
    message = "I am your friendly bot, " <> (@greetings |> Enum.shuffle |> List.first) <> "!"
    Slack.send_message(channel.id, message)
  end

  def process(message) do
    if Regex.match? ~r/^!help/, message.text do
      starting = "I'm always happy to help! Here are my currently loaded modules:\n"
      moduledocs = Enum.map(Katakuri.modules, fn m ->
        "*" <> Atom.to_string(m) <> "*: " <> m.doc
      end)
      ending = "\n(P.S., my code is available at https://github.com/cantsin/katakuri -- take a look!)"
      help = Enum.join([starting] ++ moduledocs ++ [ending], "\n")
      Slack.send_message(message.channel, help)
    end
  end

  def stop(_reason) do
    channel = Slack.get_general_channel()
    message = "Something went wrong! But don't worry, I'll be back..."
    Slack.send_message(channel.id, message)
  end
end
