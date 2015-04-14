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

Please note that all data is anonymized. But don't just take my word for it -- you may verify the code at https://raw.githubusercontent.com/cantsin/katakuri/master/lib/botmodules/happiness.ex.

To obtain anonymized and aggregated statistics at any time, type in !happystats. To opt out, type in !happyout. Thank you again!
"
  @prompt "Hello, this is your friendly neighborhood bot checking in! How are you feeling today? Please type in a number from 1 (very sad) to 5 (very happy).

(If you no longer wish to receive these prompts, then please opt out by typing in !happyout.)"
  @goodbye "OK! You have opted out of the happiness module (which makes me very sad)."

  def doc, do: @moduledoc

  def start() do
  end

  def process(message) do
    if Regex.match? ~r/^!happyme/, message.text do
      Slack.send_direct(message.user_id, @description)
      SlackDatabase.subscribe_happiness(message.user_id, true)
    end

    if Regex.match? ~r/^!happyout/, message.text do
      Slack.send_direct(message.user_id, @goodbye)
      SlackDatabase.subscribe_happiness(message.user_id, false)
    end
  end

  def stop(_reason) do
  end
end
