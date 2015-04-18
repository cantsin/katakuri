defmodule BotMotd do
  @behaviour BotModule
  @moduledoc "Message of the day. Invoke with !motd"
  @where 'djxmmx.net'

  def doc, do: @moduledoc

  def start() do
  end

  def get_motd() do
    {:ok, result} = :inet.gethostbyname(@where)
    {_, _, _, _, _, [ip]} = result
    {:ok, socket} = :gen_tcp.connect(ip, 17, [:binary, {:active, false}])
    {:ok, message} = :gen_tcp.recv(socket, 0)
    String.strip message
  end

  def process_message(message) do
    if Regex.match? ~r/^!motd/, message.text do
      Slack.send_message(message.channel, get_motd())
    end
  end

  def stop(_reason) do
  end
end
