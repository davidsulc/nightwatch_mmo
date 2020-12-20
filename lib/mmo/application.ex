defmodule MMO.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {DynamicSupervisor, name: MMO.GamesSup, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: MMO.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
