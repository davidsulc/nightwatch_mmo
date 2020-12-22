defmodule MMO do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  @games_sup MMO.GamesSup

  @doc false
  @spec games_sup() :: atom
  def games_sup(), do: @games_sup

  @doc """
  Starts a new game.

  Options:

  * `:max_players`: a non-negative integer greater than 1 indicating the
     maximum number of players the board may have. Once the player count has been reached,
     it will not be possible to spawn a new player.
     `{:error, {:invalid_option, :max_players}}` will be returned if an invalid
     value is provided.

  Returns `{:error, :max_games}` if the server has reached its configured capacity defined via
  the `:max_games` environment value.
  """
  # :board and :max_board_dimension options are also available.
  # see `MMO.GameState.spawn_player/2` for maximum player count handling
  @spec new(String.t(), Keyword.t()) ::
          DynamicSupervisor.on_start_child() | {:error, :max_games}
  def new(name, opts \\ []) do
    case DynamicSupervisor.start_child(@games_sup, {MMO.Game, Keyword.put(opts, :name, name)}) do
      {:error, :max_children} -> {:error, :max_games}
      result -> result
    end
  end

  @doc "Renders the current play session to string, and outputs it via `IO.puts/2`."
  @spec puts(pid) :: :ok
  def puts(session) do
    session
    |> MMO.PlaySession.to_string()
    |> IO.puts()
  end

  defdelegate whereis(game), to: MMO.Game
  defdelegate start_link(game), to: MMO.PlaySession
  defdelegate start_link(game, player), to: MMO.PlaySession
  defdelegate move(session, direction), to: MMO.PlaySession
  defdelegate attack(session), to: MMO.PlaySession
  defdelegate player_state(session), to: MMO.PlaySession
  defdelegate game_info(session), to: MMO.PlaySession
end
