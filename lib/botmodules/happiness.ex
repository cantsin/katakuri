# inspired by http://begriffs.com/posts/2015-03-15-tracking-joy-at-work.html
defmodule BotHappiness do
  @behaviour BotModule
  @moduledoc "Track happiness levels (with anonymized data). !happyme to opt in. !happystats for anonymized and aggregated statistics."
  @description "Thank you for opting into our happiness survey!

How this works:

- I will randomly PM you once every three days (on average).
- I will ask you how you are feeling.
- Please respond with a number from 1 (very sad) to 5 (very happy).

The scale looks like this:

1: I'm having a terrible, horrible, no-good, very bad day.
2: Sigh. Today was not one of my better days.
3: Meh, I'm doing OK.
4: I'm doing well.
5: I'm ecstatic and on top of the world!

Please note that all data is anonymized. But don't just take my word for it -- you may verify the code at https://github.com/cantsin/katakuri/blob/master/lib/botmodules/happiness.ex.

To obtain anonymized and aggregated statistics at any time, type in !happystats. To opt out, type in !happyout. Thank you again!
"
  @prompt "Hello, this is your friendly neighborhood bot checking in! How are you feeling today? Please type in a number from 1 (very sad) to 5 (very happy).

(If you no longer wish to receive these prompts, then please opt out by typing in !happyout.)"
  @goodbye "OK! You have opted out of the happiness module (which makes me very sad)."
  @polling_interval 15 # in seconds
  @interval 3 * 24 * 60 * 60 # in seconds

  def doc, do: @moduledoc

  def start do
    HappinessDB.create
    {:ok, timer_pid} = Task.start_link(fn -> happy_timer end)
    Agent.start_link(fn -> %{timer_pid: timer_pid} end, name: __MODULE__)
    query_for_happiness
  end

  def process_message(message) do
    if Regex.match? ~r/^!happyme/, message.text do
      result = HappinessDB.subscribe(message.user_id, true)
      reply = case result do
                :ok ->
                  HappinessDB.add_notification(message.user_id, random_interval)
                  @description
                _ ->
                  "You are already subscribed."
              end
      Slack.send_direct(message.user_id, reply)
    end

    if Regex.match? ~r/^!happyout/, message.text do
      result = HappinessDB.subscribe(message.user_id, false)
      reply = case result do
                :ok ->
                  HappinessDB.remove_notification(message.user_id)
                  @goodbye
                _ ->
                  "You are already unsubscribed."
              end
      Slack.send_direct(message.user_id, reply)
    end

    if Regex.match? ~r/^!happystats/, message.text do
      # TODO: make this more sophisticated -- graph the average over time.
      result = HappinessDB.get_happiness_levels
      count = Enum.reduce(result, 0, fn({val, _}, acc) -> acc + val end)
      average = if count == 0 do
                  "not enough data!"
                else
                  count / Enum.count(result)
                end
      reply = "Happiness average: #{average}"
      Slack.send_message(message.channel, reply)
    end

    if expecting_reply? message.channel, message.user_id do
      try do
        case String.to_integer message.text do
          x when x > 0 and x <= 5 ->
            HappinessDB.save_reply(x)
            HappinessDB.remove_notification(message.user_id)
            Slack.send_direct(message.user_id, "Thank you!")
          _ ->
            Slack.send_direct(message.user_id, "Please give me a value between 1 (very sad) and 5 (very happy).")
        end
      rescue
        _ in ArgumentError -> ()
      end
    end
  end

  def stop(_reason) do
  end

  defp expecting_reply?(channel, user_id) do
    dms = Slack.get_direct_messages
    in_private_conversation = Enum.find(dms, fn dm -> dm.id == channel end) |> is_map
    awaiting_reply = HappinessDB.awaiting_reply?(user_id) |> is_map
    in_private_conversation and awaiting_reply
  end

  defp next_notification do
    notifications = HappinessDB.get_notifications
    if Enum.count(notifications) == 0 do
      @polling_interval # try again later.
    else
      {_, first_date} = List.first notifications
      next_time = Enum.reduce(notifications, first_date, fn ({_, date}, acc) -> min(date, acc) end)
      next_time = next_time |> SlackDatabase.timestamp_to_calendar
      current_time = :calendar.universal_time
      {days, {hours, minutes, seconds}} = :calendar.time_difference(next_time, current_time)
      (days * 24 * 60 * 60) + (hours * 60 * 60) + (minutes * 60) + seconds
    end
  end

  defp query_for_happiness do
    pending = HappinessDB.get_current_notifications
    Enum.each(pending, fn {username, _} ->
      HappinessDB.remove_notification(username)
      Slack.send_direct(username, @prompt)
      HappinessDB.add_notification(username, random_interval)
    end)

    next_time = next_notification
    next = max(0, next_time) + 5 * 60 # add some padding
    timer_pid = Agent.get(__MODULE__, &Map.get(&1, :timer_pid))
    send(timer_pid, {:refresh, next, self()})
  end

  defp happy_timer do
    receive do
      {:refresh, interval, _} ->
        # debugging.
        # general = Slack.get_general_channel
        # Slack.send_message(general.id, "Reloading happiness: timer set to #{interval} seconds")
        :timer.sleep(interval * 1000)
        query_for_happiness
        happy_timer
    end
  end

  defp random_interval do
    :random.uniform * @interval + @interval / 2
  end
end

defmodule HappinessDB do
  @behaviour BotModule.DB

  def create do
    SlackDatabase.write!("CREATE TABLE IF NOT EXISTS subscriptions(id serial PRIMARY KEY, username CHARACTER(9), subscribed BOOLEAN)")
    SlackDatabase.write!("CREATE TABLE IF NOT EXISTS notifications(id serial PRIMARY KEY, username CHARACTER(9), date TIMESTAMPTZ)")
    SlackDatabase.write!("CREATE TABLE IF NOT EXISTS happiness(id serial PRIMARY KEY, value INTEGER, created TIMESTAMPTZ DEFAULT current_timestamp)")
  end

  def save_reply(value) do
    SlackDatabase.write!("INSERT INTO happiness(value) VALUES($1)", [value])
  end

  def add_notification(username, interval) do
    SlackDatabase.write!("INSERT INTO notifications(username, date) VALUES($1, NOW() + interval '$2 seconds')", [username, interval])
  end

  def remove_notification(username) do
    SlackDatabase.write!("DELETE FROM notifications WHERE username = $1", [username])
  end

  def get_notifications do
    result = SlackDatabase.query?("SELECT username, date FROM notifications")
    result.rows
  end

  def get_current_notifications do
    result = SlackDatabase.query?("SELECT username, date FROM notifications WHERE date <= NOW()")
    result.rows
  end

  def subscribe(username, subscribed) do
    result = SlackDatabase.query?("SELECT subscribed FROM subscriptions WHERE username = $1", [username])
    if result.num_rows == 0 do
      SlackDatabase.write!("INSERT INTO subscriptions(username, subscribed) VALUES($1, $2)", [username, subscribed])
      :ok
    else
      SlackDatabase.write!("UPDATE subscriptions SET subscribed = $2 WHERE username = $1", [username, subscribed])
      {current} = List.first result.rows
      if current != subscribed do
        :ok
      else
        :error
      end
    end
  end

  def get_happiness_levels do
    result = SlackDatabase.query?("SELECT value, created FROM happiness")
    result.rows
  end

  def awaiting_reply?(username) do
    result = SlackDatabase.query?("SELECT date FROM notifications WHERE username = $1", [username])
    if result.num_rows == 0 do
      nil
    else
      {date} = List.first result.rows
      date
    end
  end
end
