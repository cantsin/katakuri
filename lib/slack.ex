defmodule Slack do
  @moduledoc "Agent to retain information about this Slack."

  # Here, we assume that id never changes. This may very well be wrong.
  defmodule User do
    defstruct [:id, :name, :status, :presence]
  end

  defmodule Channel do
    defstruct [:id, :name, :is_archived, :is_general, :is_member]
  end

  defmodule DirectMessage do
    defstruct [:id, :is_open, :user]
  end

  def start_link do
    {:ok, message_pid} = Task.start_link(fn -> send_throttled_message end)
    Agent.start_link(fn -> %{message_pid: message_pid} end, name: __MODULE__)
  end

  def set_socket(socket) do
    Agent.update(__MODULE__, &Map.put(&1, :socket, socket))
    Agent.update(__MODULE__, &Map.put(&1, :message_count, 0))
  end

  def update_direct_messages(direct_messages) do
    Agent.update(__MODULE__, &Map.put(&1, :direct_messages, direct_messages))
  end

  def get_direct_messages do
    Agent.get(__MODULE__, &Map.get(&1, :direct_messages))
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

  def get_active_channels do
    Enum.filter(get_channels(), fn channel -> !channel.is_archived end)
  end

  def get_joined_channels do
    Enum.filter(get_channels(), fn channel -> channel.is_member end)
  end

  def get_general_channel do
    Enum.find(get_channels(), fn channel -> channel.is_general end)
  end

  def send_message(channel, text) do
    message_count = Agent.get_and_update(__MODULE__, fn vars ->
      { vars.message_count, Map.put(vars, :message_count, vars.message_count + 1) }
    end)
    # Slack imposes certain restrictions on messages, so we'll follow them as well.
    text = String.replace text, ">", "&gt;"
    text = String.replace text, "<", "&lt;"
    text = String.replace text, "&", "&amp;"
    text = String.slice text, 0..4000
    message = %{id: message_count,
                type: "message",
                channel: channel,
                text: text}
    {:ok, raw} = Poison.encode message
    message_pid = Agent.get(__MODULE__, &Map.get(&1, :message_pid))
    send(message_pid, {:send, raw, self()})
  end

  def send_direct(whom, text) do
    channel = Enum.find(get_direct_messages, fn im -> im.user == whom end)
    if channel != nil do
      send_message(channel.id, text)
      {:ok}
    else
      {:error, :no_direct_message}
    end
  end

  defp send_throttled_message do
    receive do
      {:send, message, _} ->
        socket = Agent.get(__MODULE__, &Map.get(&1, :socket))
        :websocket_client.send({:text, message}, socket)
        # the Slack spec says not to send more than once a second, but
        # we'll experiment with lower values for now.
        :timer.sleep(250)
        send_throttled_message
    end
  end
end
