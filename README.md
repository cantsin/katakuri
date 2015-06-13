Katakuri
========

A Slack bot, written in Elixir, with module support. **This bot is experimental, and it is early days yet.**

Please note that due to a longstanding Slack mis-feature, [bots cannot join rooms](https://github.com/slackhq/node-slack-client/issues/26); they have to be invited in explicitly.

In case anyone is wondering, the name comes from an [obscure Korean film](http://en.wikipedia.org/wiki/The_Happiness_of_the_Katakuris).

Currently there are four modules:

- welcome: Emits a friendly message upon joining and also responds to !help.
- logger: Logs all messages.
- motd: Message of the day.
- happiness: (in progress) Quantify happiness levels of subscribers over time.

There is a mix task provided to start the bot. Simply run:

> mix StartBot -t <slack_api_token>
