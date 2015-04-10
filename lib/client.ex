defmodule Client do
  @behaviour :websocket_client_handler
  @moduledoc "Automatically update users and channels for a given Slack."

  # Our abstraction around a Slack message.
  defmodule Message do
    defstruct [:channel, :user, :ts, :text, :edited]
  end

  def init([info, modules], socket) do
    # Set up the Slack agent.
    Slack.start_link()
    Slack.set_socket(socket)
    process_users(info.users) |> Slack.update_users
    process_channels(info.channels) |> Slack.update_channels

    # Set up our state.
    state = %{modules: modules}

    # Initialize modules.
    Enum.each(state.modules, fn m -> m.start() end)

    {:ok, state}
  end

  def websocket_handle({:text, message}, _connection, state) do
    event = message |> :jsx.decode |> JSONMap.to_map
    IO.inspect event

    # Process a response.
    if Map.has_key? event, :reply_to do
      event = Map.put(event, :type, "response")
    end

    # Too bad Erlang/Elixir does not allow introspection of private
    # methods. Would make this a bit cleaner.
    case event.type do
      "user_change" -> user_change(event) |> Slack.update_users
      "presence_change" -> presence_change(event) |> Slack.update_users
      "channel_rename" -> channel_rename(event) |> Slack.update_channels
      "channel_created" -> channel_created(event) |> Slack.update_channels
      "channel_deleted" -> channel_deleted(event) |> Slack.update_channels
      "channel_archive" -> channel_archive(event) |> Slack.update_channels
      "channel_unarchive" -> channel_unarchive(event) |> Slack.update_channels
      "message" ->
        message = process_message(event)
        Enum.each(state.modules, fn m -> m.process(message) end)
      _ ->
    end

    {:ok, state}
  end

  def websocket_handle({:ping, data}, _connection, state) do
    {:reply, {:pong, data}, state}
  end

  def websocket_info(:start, _connection, state) do
    {:ok, state}
  end

  def websocket_terminate(reason, _connection, state) do
    Enum.each(state.modules, fn m -> m.stop(reason) end)
    :ok
  end

  defp presence_change(event) do
    users = Slack.get_users()
    attrs = %Slack.User{presence: event.presence}
    update_id(users, event.user, attrs)
  end

  defp user_change(event) do
    users = Slack.get_users()
    attrs = %Slack.User{name: event.user.name, status: event.user.status}
    update_id(users, event.user.id, attrs)
  end

  defp channel_rename(event) do
    channels = Slack.get_channels()
    attrs = %Slack.Channel{name: event.channel.name}
    update_id(channels, event.channel.id, attrs)
  end

  defp channel_archive(event) do
    channels = Slack.get_channels()
    attrs = %Slack.Channel{is_archived: true}
    update_id(channels, event.channel, attrs)
  end

  defp channel_unarchive(event) do
    channels = Slack.get_channels()
    attrs = %Slack.Channel{is_archived: false}
    update_id(channels, event.channel, attrs)
  end

  defp channel_created(event) do
    channels = Slack.get_channels()
    channel = %Slack.Channel{id: event.channel.id,
                             name: event.channel.name,
                             is_archived: false}
    channels ++ [channel]
  end

  defp channel_deleted(event) do
    channels = Slack.get_channels()
    {:ok, channel} = find_by_id(channels, event.channel)
    List.delete(channels, channel)
  end

  defp process_message(event) do
    # Slack stores references to names/channels by <@id>. Here, we
    # transform these references to the associated name for ease of
    # debugging and logging.
    edited = Map.has_key? event, :message
    text = if edited do event.message.text else event.text end
    matches = Regex.scan(~r/<@([^>]+)>/, text)
    all_items = Slack.get_users() ++ Slack.get_channels()
    {_, line} = Enum.map_reduce(matches, text, fn(match, acc) ->
      [full, id] = match
      {:ok, item} = find_by_id(all_items, id)
      {id, String.replace(acc, full, "@" <> item.name)}
    end)
    %Message{channel: event.channel,
             user: event.user,
             ts: event.ts,
             text: line,
             edited: edited}
  end

  defp process_users(users) do
    Enum.map(users, fn u ->
      %Slack.User{id: u.id, name: u.name, status: u.status, presence: u.presence}
    end)
  end

  defp process_channels(channels) do
    Enum.map(channels, fn c ->
      %Slack.Channel{id: c.id, name: c.name, is_archived: c.is_archived}
    end)
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
end
