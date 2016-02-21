defmodule Katakuri.Mixfile do
  use Mix.Project

  def project do
    [app: :katakuri,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps]
  end

  def application do
    [applications: [:logger, :tzdata]]
  end

  defp deps do
    [{:websocket_client, github: "jeremyong/websocket_client"},
     {:ibrowse, github: "cmullaparthi/ibrowse", tag: "v4.2.2"},
     {:httpotion, "~> 2.0.0"},
     {:poison, github: "devinus/poison"},
     {:postgrex, "~> 0.11.1"},
     {:logger_file_backend, github: "onkel-dirtus/logger_file_backend"},
     {:timex, "~> 1.0.1"}
    ]
  end
end
