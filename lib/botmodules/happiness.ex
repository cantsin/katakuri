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

  def doc, do: @moduledoc

  def start() do
    # TODO: start timer
  end

  def process(message) do
    if Regex.match? ~r/^!happyme/, message.text do
      result = SlackDatabase.subscribe_happiness(message.user_id, true)
      reply = case result do
                :ok -> @description
                _ -> "You are already subscribed."
              end
      Slack.send_direct(message.user_id, reply)
    end

    if Regex.match? ~r/^!happyout/, message.text do
      result = SlackDatabase.subscribe_happiness(message.user_id, false)
      reply = case result do
                :ok -> @goodbye
                _ -> "You are already unsubscribed."
              end
      Slack.send_direct(message.user_id, reply)
    end

    if Regex.match? ~r/^!happystats/, message.text do
      result = SlackDatabase.get_happiness_levels
      reply = "#{inspect result}"
      # TODO: metrics?
      Slack.send_message(message.channel, reply)
    end

    if expecting_reply? message do
      try do
        case String.to_integer message.text do
          x when x > 0 and x <= 5 ->
            SlackDatabase.save_reply(message.user_id, x)
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

  # make sure we are on a DM and that we are awaiting a reply.
  defp expecting_reply?(message) do
    dms = Slack.get_direct_messages
    awaiting_reply = SlackDatabase.awaiting_reply? message.user_id
    awaiting_reply and Enum.find(dms, fn dm -> dm.id == message.channel end) |> is_map
  end
end
