defmodule MMO do
  @moduledoc """
  Documentation for `MMO`.
  """

  @games_sup MMO.GamesSup

  @doc false
  @spec games_sup() :: atom
  def games_sup(), do: @games_sup

  @doc """
  Starts a new game.

  Returns `{:error, :max_games}` if the server has reached its configured capacity defined via
  the `:max_games` environment value.
  """
  # TODO document options
  @spec new(String.t(), Keyword.t()) ::
          DynamicSupervisor.on_start_child() | {:error, :max_games}
  def new(name, opts \\ []) do
    case DynamicSupervisor.start_child(@games_sup, {MMO.Game, Keyword.put(opts, :name, name)}) do
      {:error, :max_children} -> {:error, :max_games}
      result -> result
    end
  end

  # TODO document
  def puts(session) do
    session
    |> MMO.PlaySession.to_string()
    |> IO.puts()
  end

  # TODO document
  defdelegate whereis(game), to: MMO.Game
  defdelegate start_link(game), to: MMO.PlaySession
  defdelegate start_link(game, player), to: MMO.PlaySession
  defdelegate move(session, direction), to: MMO.PlaySession
  defdelegate attack(session), to: MMO.PlaySession
end
