defmodule Mix.Tasks.StartBot do

  use Mix.Task

  @shortdoc "Start a slack bot with the given API token."

  def sleep do
    :timer.sleep(1)
    sleep
  end

  def run(args) do
    Mix.Task.run "app.start", args
    {options, _, _} = OptionParser.parse args, switches: [token: :string], aliases: [t: :token]
    if Keyword.get(options, :token) do
      token = Keyword.fetch!(options, :token)
      IO.puts "Connecting to Slack with the token '#{token}'"
      Katakuri.init token
      sleep
    else
      IO.puts "Error: please pass in a token."
      IO.puts ""
      IO.puts "Example usage:"
      IO.puts "  mix StartBot -t <slack_api_token>"
    end
  end
end
