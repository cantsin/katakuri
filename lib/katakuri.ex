defmodule SlackServer do
  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, {}, [name: :katakuri])
    [token, modules] = state
    {:ok, raw_result} = Rtm.start(token)
    {:ok, _} = :websocket_client.start_link(raw_result.url, Client, [raw_result, modules])
  end

  def handle_call(_what, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_what, state) do
    {:noreply, state}
  end
end

defmodule Katakuri do
  import Supervisor.Spec

  @modules [BotWelcome]

  def init(token) do
    children = [
      worker(SlackServer, [[token, @modules]])
    ]
    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)
  end
end
