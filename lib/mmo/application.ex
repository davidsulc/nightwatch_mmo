defmodule MMO.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    max_concurrent_games = Application.get_env(:mmo, :max_games, :infinity)

    children = [
      {Registry, keys: :unique, name: Registry.MMO.Games},
      {DynamicSupervisor,
       name: MMO.games_sup(), strategy: :one_for_one, max_children: max_concurrent_games}
    ]

    opts = [strategy: :one_for_one, name: MMO.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
