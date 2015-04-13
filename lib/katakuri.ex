defmodule SlackServer do
  use GenServer

  @url "https://slack.com/api/rtm.start?token="

  def start_link(state) do
    GenServer.start_link(__MODULE__, {}, [name: :server])
    [token, modules] = state
    {:ok, raw_result} = process_token(token)
    {:ok, _} = :websocket_client.start_link(raw_result.url, Client, [raw_result, modules])
  end

  def handle_call(_what, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_what, state) do
    {:noreply, state}
  end

  defp process_token(token) do
    HTTPotion.start
    response = HTTPotion.get(@url <> token)
    Poison.Parser.parse(response.body, keys: :atoms)
  end
end

defmodule Katakuri do
  import Supervisor.Spec

  @modules [BotWelcome, BotMotd, BotLogger, BotHappiness]

  def modules, do: @modules

  def init(token) do
    children = [
      worker(SlackDatabase, [[]]),
      worker(SlackServer, [[token, @modules]]),
    ]
    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)
  end
end
