defmodule Client do
  @behaviour :websocket_client_handler
  @moduledoc "Automatically update users and channels for a given Slack."

  require Logger

  # Our abstraction around a Slack message.
  defmodule Message do
    defstruct [:channel, :user, :user_id, :ts, :text, :edited, :raw]
  end

  def init([info, modules], socket) do
    Logger.info "Slack client started with #{inspect [info, modules]}"

    # Set up the Slack agent.
    Slack.start_link()
    Slack.set_socket(socket)

    users = process_users(info.users)
    channels = process_channels(info.channels)
    direct_messages = process_direct_messages(info.ims)
    Slack.update_users users
    Slack.update_channels channels
    Slack.update_direct_messages direct_messages

    # Set up our state.
    raw_ids = Enum.map(users ++ channels, fn i -> {i.id, i.name} end)
    ids = Enum.into(raw_ids, %{})
    state = %{modules: modules,
              ids: ids}

    # Initialize modules.
    Enum.each(state.modules, fn m -> m.start() end)

    {:ok, state}
  end

  def websocket_handle({:text, message}, _connection, state) do
    Logger.info message
    event = Poison.Parser.parse!(message, keys: :atoms)

    # Reconfigure an acknowledged reply from the bot to be something
    # other than message, which it is not.
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
        message = process_message(state.ids, event)
        Enum.each(state.modules, fn m -> m.process(message) end)
      "user_typing" -> () # no-op
      "response" -> () # no-op
      "hello" -> () # no-op
      _ ->
        Logger.error "unknown event type: #{event.type}"
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
    Logger.info "Slack client terminated with reason #{reason}"
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

  def process_message(ids, event) do
    # Slack stores references to names/channels by <@id>. Here, we
    # transform these references to the associated name for ease of
    # debugging and logging.
    edited = Map.has_key? event, :message
    text = if edited do event.message.text else event.text end
    user = if edited do event.message.user else event.user end
    username = Dict.get(ids, user)
    matches = Regex.scan(~r/<@([^>|]+).*>/, text)
    {_, text} = Enum.map_reduce(matches, text, fn(match, acc) ->
      [full, id] = match
      name = Dict.get(ids, id)
      {id, String.replace(acc, full, name)}
    end)
    %Message{channel: event.channel,
             user: username,
             user_id: user,
             ts: event.ts,
             text: text,
             edited: edited,
             raw: event}
  end

  defp process_users(users) do
    Enum.map(users, fn u ->
      %Slack.User{id: u.id, name: u.name, status: u.status, presence: u.presence}
    end)
  end

  defp process_channels(channels) do
    Enum.map(channels, fn c ->
      %Slack.Channel{id: c.id,
                     name: c.name,
                     is_archived: c.is_archived,
                     is_general: c.is_general,
                     is_member: c.is_member}
    end)
  end

  defp process_direct_messages(direct_messages) do
    Enum.map(direct_messages, fn im ->
      %Slack.DirectMessage{id: im.id, is_open: im.is_open, user: im.user}
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
