defmodule Slack do
  @moduledoc "Agent to retain information about this Slack."

  # Here, we assume that id never changes. This may very well be wrong.
  defmodule User do
    defstruct [:id, :name, :status, :presence]
  end

  defmodule Channel do
    defstruct [:id, :name, :is_archived]
  end

  def start_link do
    Agent.start_link(fn -> Map.new end, name: __MODULE__)
  end

  def set_socket(socket) do
    Agent.update(__MODULE__, &Map.put(&1, :socket, socket))
    Agent.update(__MODULE__, &Map.put(&1, :message_count, 0))
  end

  def update_users(users) do
    Agent.update(__MODULE__, &Map.put(&1, :users, users))
  end

  def get_users do
    Agent.get(__MODULE__, &Map.get(&1, :users))
  end

  def update_channels(channels) do
    Agent.update(__MODULE__, &Map.put(&1, :channels, channels))
  end

  def get_channels do
    Agent.get(__MODULE__, &Map.get(&1, :channels))
  end

  def send_message(channel, text) do
    message_count = Agent.get_and_update(__MODULE__, fn vars ->
      { vars.message_count, Map.put(vars, :message_count, vars.message_count + 1) }
    end)
    socket = Agent.get(__MODULE__, &Map.get(&1, :socket))
    message = [{:id, message_count},
               {:type, "message"},
               {:channel, channel},
               {:text, text}]
    raw = :jsx.encode message
    :websocket_client.send({:text, raw}, socket)
  end
end
