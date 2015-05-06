defmodule SlackServer do

  use GenServer

  require Logger

  @url "https://slack.com/api/"

  def start_link(args) do
    HTTPotion.start
    GenServer.start_link(__MODULE__, args, [name: :server])
  end

  def init([token]) do
    {:ok, raw_result} = connect(token)
    {:ok, _} = :websocket_client.start_link(raw_result.url, Client, [raw_result])
    state = %{token: token}
    {:ok, state}
  end

  def handle_call({:open_direct_message, [whom, text]}, _from, state) do
    response = HTTPotion.get(@url <> "chat.postMessage?token=" <> state.token <> "&channel=" <> whom <> "&text=" <> text)
    {:ok, _} = Poison.Parser.parse(response.body, keys: :atoms)
    {:reply, :ok, state}
  end

  def handle_call(_what, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_what, state) do
    {:noreply, state}
  end

  defp connect(token) do
    response = HTTPotion.get(@url <> "rtm.start?token=" <> token)
    Poison.Parser.parse(response.body, keys: :atoms)
  end

  def open_direct_message(whom, text) do
    GenServer.call(:server, {:open_direct_message, [whom, text]})
  end
end

defmodule Katakuri do
  import Supervisor.Spec

  @modules [BotWelcome, BotMotd, BotLogger, BotHappiness, BotExtraneous]

  def modules, do: @modules
  def emit_greeting, do: false

  def init(token) do
    children = [
      worker(SlackDatabase, [[]]),
      worker(SlackServer, [[token]]),
      supervisor(BotModuleManager, [[]]),
    ]
    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)
  end
end
