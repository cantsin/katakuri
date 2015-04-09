defmodule Client do
  @behaviour :websocket_client_handler
  @moduledoc "Automatically update users and channels for a given Slack."

  defmodule User do
    defstruct [:id, :name, :status, :presence]
  end
  defmodule Channel do
    defstruct [:id, :name, :is_archived]
  end

  def init(info, socket) do
    state = %{raw: info,
              socket: socket,
              users: process_users(info.users),
              channels: process_channels(info.channels)}
    IO.inspect state.users
    IO.inspect state.channels
    {:ok, state}
  end

  def websocket_handle({:text, message}, _connection, state) do
    event = message |> :jsx.decode |> JSONMap.to_map
    IO.inspect event
    {:ok, state}
  end

  def websocket_handle({:ping, data}, _connection, state) do
    {:reply, {:pong, data}, state}
  end

  def websocket_info(:start, _connection, state) do
    {:ok, state}
  end

  def websocket_terminate(reason, _connection, _state) do
    IO.puts "terminated: " <> reason
    :ok
  end

  defp process_users(users) do
    Enum.map(users, fn u ->
      %User{id: u.id, name: u.name, status: u.status, presence: u.presence}
    end)
  end

  defp process_channels(channels) do
    Enum.map(channels, fn c ->
      %Channel{id: c.id, name: c.name, is_archived: c.is_archived}
    end)
  end
end
