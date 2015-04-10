defmodule Client do
  @behaviour :websocket_client_handler
  @moduledoc "Automatically update users and channels for a given Slack."

  # Our abstraction around a Slack message.
  defmodule Message do
    defstruct [:channel, :user, :ts, :text, :edited]
  end

  def init([info, modules], socket) do
    Slack.start_link()
    Slack.set_socket(socket)
    state = %{#raw: info,
              modules: modules,
              socket: socket,
              users: process_users(info.users),
              channels: process_channels(info.channels),
              count: 0}
    IO.inspect state.users
    IO.inspect state.channels
    channel = List.first state.channels
    Slack.send_message(channel.id, "Greetings.")
    # initialize modules.
    Enum.each(state.modules, fn m -> m.start() end)
    {:ok, state}
  end

  # Too bad Erlang/Elixir does not allow introspection of private
  # methods. Would make this a bit cleaner.
  #
  # Assume that id never changes. This may very well be wrong.
  def websocket_handle({:text, message}, _connection, state) do
    event = message |> :jsx.decode |> JSONMap.to_map
    IO.inspect event

    # Process a response.
    if Map.has_key? event, :reply_to do
      state = Map.put(state, :count, state.count + 1)
      event = Map.put(event, :type, "response")
    end

    users = case event.type do
              "presence_change" ->
                attrs = %Slack.User{presence: event.presence}
                update_id(state.users, event.user, attrs)
              "user_change" ->
                attrs = %Slack.User{name: event.user.name, status: event.user.status}
                update_id(state.users, event.user.id, attrs)
              _ ->
                state.users
            end
    state = Map.put(state, :users, users)

    channels = case event.type do
                 "channel_rename" ->
                   attrs = %Slack.Channel{name: event.channel.name}
                   update_id(state.channels, event.channel.id, attrs)
                 "channel_archive" ->
                   attrs = %Slack.Channel{is_archived: true}
                   update_id(state.channels, event.channel, attrs)
                 "channel_unarchive" ->
                   attrs = %Slack.Channel{is_archived: false}
                   update_id(state.channels, event.channel, attrs)
                 "channel_created" ->
                   channel = %Slack.Channel{id: event.channel.id,
                                      name: event.channel.name,
                                      is_archived: false}
                   state.channels ++ [channel]
                 "channel_deleted" ->
                   {:ok, channel} = find_by_id(state.channels, event.channel)
                   List.delete(state.channels, channel)
                 _ ->
                   state.channels
               end
    state = Map.put(state, :channels, channels)

    if event.type == "message" do
      # transform any ids to the associated name.
      edited = Map.has_key? event, :message
      text = if edited do event.message.text else event.text end
      matches = Regex.scan(~r/<@([^>]+)>/, text)
      {_, line} = Enum.map_reduce(matches, text, fn(match, acc) ->
        [full, id] = match
        {:ok, item} = find_by_id(state.users ++ state.channels, id)
        {id, String.replace(acc, full, "@" <> item.name)}
      end)

      message = %Message{channel: event.channel,
                         user: event.user,
                         ts: event.ts,
                         text: line,
                         edited: edited}
      Enum.each(state.modules, fn m -> m.process(message) end)
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
      %Slack.User{id: u.id, name: u.name, status: u.status, presence: u.presence}
    end)
  end

  defp process_channels(channels) do
    Enum.map(channels, fn c ->
      %Slack.Channel{id: c.id, name: c.name, is_archived: c.is_archived}
    end)
  end
end
