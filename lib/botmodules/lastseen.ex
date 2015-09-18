defmodule BotLastSeen do
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
            ts = String.to_float time
            # TODO: calculate relative time
            "#{nick} was last seen in ${where}"
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
end

defmodule LastSeenDB do
  @behaviour BotModule.DB

  def query_user(user_id) do
    result = SlackDatabase.query?("SELECT message->'user', message->'ts' FROM messages WHERE message ->> 'user' = '$1'", [user_id])
    result.rows
  end
end
