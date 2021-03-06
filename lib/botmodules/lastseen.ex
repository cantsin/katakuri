defmodule BotLastSeen do
  use Timex

  @behaviour BotModule
  @moduledoc "Report when an user was last seen."

  def doc, do: @moduledoc

  def start do

  end

  def process_message(message) do
    if Regex.match? ~r/^!lastseen ([^ ]+)$/, message.text do
      [_, nick] = Regex.run ~r/^!lastseen ([^ ]+)$/, message.text
      users = Slack.get_users
      user = Enum.find(users, fn(user) -> user.name == nick end)
      user_id = user.id
      msg =
        if user_id == nil do
          "#{nick} does not seem to be an user here."
        else
          rows = LastSeenDB.query_user user_id
          if (Enum.count rows) == 0 do
            "I've never seen #{nick} anywhere."
          else
            {where, time} = List.last rows
            ts = time |> String.to_float |> Time.to_timestamp(:secs)
            current_ts = message.ts |> String.to_float |> Time.to_timestamp(:secs)
            diff = Time.sub(current_ts, ts) |> Date.from(:timestamp)
            elapsed = format_time_difference diff
            channels = Slack.get_channels
            channel = Enum.find(channels, fn(channel) -> channel.id == where end)
            channel_name =
              if channel == nil do "a private channel" else "#" <> channel.name end
            "#{nick} was last seen in #{channel_name} #{elapsed}"
          end
        end
      Slack.send_message(message.channel, msg)
    else
      if Regex.match? ~r/^!lastseen/, message.text do
        help = "usage: !lastseen nickname"
        Slack.send_message(message.channel, help)
      end
    end
  end

  def stop(_reason) do

  end

  defp pluralize(n, str) do
    # overly simple: does not account for 'y' and definitely not unicode-aware!
    if n != 1 do str <> "s" else str end
  end

  defp format_time_difference(diff) do
    year = diff.year - 1970
    str = ""
    if year != 0 do
      p = pluralize(year, "year")
      str = "#{year} #{p} "
    end
    if diff.month != 1 do
      p = pluralize(diff.month, "month")
      str = str <> "#{diff.month} #{p} "
    end
    if diff.day != 1 do
      p = pluralize(diff.day, "day")
      str = str <> "#{diff.day} #{p} "
    end
    if diff.hour != 0 do
      p = pluralize(diff.hour, "hour")
      str = str <> "#{diff.hour} #{p} "
    end
    if diff.minute != 0 do
      p = pluralize(diff.minute, "minute")
      str = str <> "#{diff.minute} #{p} "
    end
    if (String.length str) != 0 do
      str <> "ago"
    else
      "just now"
    end
  end
end

defmodule LastSeenDB do
  @behaviour BotModule.DB

  def create do

  end

  def query_user(user_id) do
    result = SlackDatabase.query?("SELECT message->'channel', message->'ts' FROM messages WHERE message ->> 'user' = $1 ORDER BY id", [user_id])
    result.rows
  end
end
