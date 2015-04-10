defmodule BotWelcome do

  @behaviour BotModule

  def start() do
    IO.puts "*** started"
  end

  def process(_message) do

  end

  def stop(_reason) do

  end
end
