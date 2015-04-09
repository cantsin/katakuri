defmodule Client do
  @behaviour :websocket_client_handler
  @moduledoc "Automatically update users and channels for a given Slack."

  # Assume that id never changes. This may very well be wrong.
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

    # Erlang/Elixir does not allow introspection of private methods. Pity.
    users = case event.type do
      "presence_change" ->
        attrs = %User{presence: event.presence}
        update_id(state.users, event.user, attrs)
      "user_change" ->
        attrs = %User{name: event.user.name, status: event.user.status}
        update_id(state.users, event.user.id, attrs)
      _ -> state.users
    end

    # TODO for channels:
    # channel_name, channel_archive, channel_unarchive, channel_created, channel_deleted

    IO.inspect users

    {:ok, %{state | :users => users}}
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

  defp update_id(what, id, attrs) do
    Enum.map(what, fn item ->
      if item.id == id do
        # a bit convoluted. basically only override when attrs has nil values
        Map.merge(attrs, item, fn(_k, v1, v2) ->
          if is_nil v1 do
            v2
          else
            v1
          end
        end)
      else
        item
      end
    end)
  end

  def find_by_id(what, id) do
    result = Enum.find(what, fn x -> x.id == id end)
    if is_nil result do
      {:error, "No such id."}
    else
      {:ok, result}
    end
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
