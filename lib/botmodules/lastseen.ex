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
      user_id = Enum.find(users, fn(user) -> user.name == nick end)
      message =
        if user_id == nil do
          "#{nick} does not seem to be an user here."
        else
          rows = LastSeenDB.query_user user_id
          if rows == nil do
            "I've never seen #{nick} anywhere."
          else
            # TODO: anonymize private channel names.
            {where, time} = List.last rows
            ts = time |> String.to_float |> Time.to_timestamp(:secs)
            diff = Time.sub(Time.now, ts) |> Date.from(:timestamp)
            elapsed = format_time_difference diff
            "#{nick} was last seen in #{where} #{elapsed}"
          end
        end
      Slack.send_message(message.channel, message)
    else
      if Regex.match? ~r/^!lastseen/, message.text do
        help = "usage: !lastseen <nick>"
        Slack.send_message(message.channel, help)
      end
    end
  end

  def stop(_reason) do

  end

  defp pluralize(n, str) do
    if n != 0 do str <> "s" else str end
  end

  defp format_time_difference(diff) do
    year = diff.year - 1970
    str = ""
    if year != 0 do
      p = pluralize(year, "year")
      str = "#{year} #{p} "
    end
    if diff.month != 0 do
      p = pluralize(diff.month, "month")
      str = str <> "#{diff.month} #{p} "
    end
    if diff.day != 0 do
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

  def query_user(user_id) do
    result = SlackDatabase.query?("SELECT message->'user', message->'ts' FROM messages WHERE message ->> 'user' = '$1'", [user_id])
    result.rows
  end
end
