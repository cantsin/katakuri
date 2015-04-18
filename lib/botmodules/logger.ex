defmodule BotLogger do
  @behaviour BotModule
  @moduledoc "Log all messages."

  require Logger

  def doc, do: @moduledoc

  def start() do
    LoggerDB.create
  end

  def process_message(message) do
    LoggerDB.write_message(message.raw)
    line = format_message(message.raw, message.ts, message.user, message.text)
    Logger.info line
  end

  def format_message(event, ts, username, line) do
    if Map.has_key? event, :subtype do
      case event.subtype do
        "me_message" -> format_me(ts, username, line)
        "message_changed" ->
          if Map.has_key? event.message, :subtype do
            case event.message.subtype do
              "me_message" -> format_me(ts, username, line) |> format_edited
              _ -> format_chat(ts, username, line) |> format_edited
            end
          else
            format_chat(ts, username, line) |> format_edited
          end
        "channel_name" -> format_rename(ts, line)
        _ ->
          "unknown " <> line
          Logger.error "could not format message from event #{inspect event}"
      end
    else
      format_chat(ts, username, line)
    end
  end

  defp format_me(ts, username, line) do
    format_time(ts) <> " * " <> username <> " " <> line
  end

  defp format_chat(ts, username, line) do
    format_time(ts) <> " " <> username <> ": " <> line
  end

  defp format_edited(line) do
    "[edited] " <> line
  end

  defp format_rename(ts, line) do
    format_time(ts) <> " " <> line
  end

  def format_time(milliseconds) do
    ms = String.to_float milliseconds
    basetime = :calendar.datetime_to_gregorian_seconds({{1970,1,1}, {0,0,0}})
    seconds = basetime + ms |> round
    {{y, m, d}, {h, min, s}} = :calendar.gregorian_seconds_to_datetime seconds
    "#{m}-#{d}-#{y} #{h}:#{min}:#{s}"
  end

  def stop(_reason) do

  end
end

defmodule LoggerDB do
  @behaviour BotModule.DB

  def create do
    SlackDatabase.write!("CREATE TABLE IF NOT EXISTS messages(id serial PRIMARY KEY, message JSON)")
  end

  def write_message(message) do
    SlackDatabase.write!("INSERT INTO messages(message) VALUES($1)", [message])
  end
end
