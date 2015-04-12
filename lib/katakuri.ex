defmodule SlackServer do
  use GenServer

  @url "https://slack.com/api/rtm.start?token="

  def start_link(state) do
    GenServer.start_link(__MODULE__, {}, [name: :katakuri])
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
    result = response.body |> to_string |> :jsx.decode |> JSONMap.to_map
    %{ok: validated} = result
    if validated do
      {:ok, result}
    else
      {:error, "Token is incorrect."}
    end
  end
end

defmodule Katakuri do
  import Supervisor.Spec

  @modules [BotWelcome, BotMotd, BotLogger]

  def modules, do: @modules

  def init(token) do
    children = [
      worker(SlackServer, [[token, @modules]])
    ]
    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)
  end
end
