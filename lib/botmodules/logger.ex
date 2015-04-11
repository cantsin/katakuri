defmodule BotLogger do
  @behaviour BotModule
  @moduledoc "Log all messages."

  def doc, do: @moduledoc

  def start() do

  end

  def process(message) do
    line = format_message(message.raw, message.user, message.text)
    IO.puts line
  end

  def format_message(event, username, line) do
    if Map.has_key? event, :subtype do
      case event.subtype do
        "me_message" -> format_me(username, line)
        "message_changed" ->
          if Map.has_key? event.message, :subtype do
            case event.message.subtype do
              "me_message" -> format_me(username, line) |> format_edited
              _ -> format_chat(username, line) |> format_edited
            end
          else
            format_chat(username, line) |> format_edited
          end
        _ -> "unknown " <> line
      end
    else
      format_chat(username, line)
    end
  end

  defp format_me(username, line) do
    "* " <> username <> " " <> line
  end

  defp format_chat(username, line) do
    username <> ": " <> line
  end

  defp format_edited(line) do
    "[edited] " <> line
  end

  def stop(_reason) do

  end
end
