defmodule MMO.GameTest do
  use ExUnit.Case, async: true
  doctest MMO.Game

  alias MMO.{Game, GameState}

  @player "me"

  setup do
    {:ok, game_state} = GameState.new()
    {:ok, game_state} = GameState.spawn_player_at(game_state, @player, {1, 1})
    {:ok, state} = Game.State.new(game_state)

    %{state: state}
  end

  defp player_in?(%GameState{player_info: player_info}, player, coord) do
    assert get_in(player_info, [player, :position]) == coord
  end

  describe "move" do
    test "updates the player's location", %{state: state} do
      assert player_in?(state.game_state, @player, {1, 1})

      {:reply, :ok, updated_state} =
        Game.handle_call({:move, @player, {1, 2}}, {self(), make_ref()}, state)

      assert player_in?(updated_state.game_state, @player, {1, 2})
    end

    test "broadcasts the updated state to all players", %{state: state} do
      {:reply, :ok, _updated_state} =
        Game.handle_call({:move, @player, {1, 2}}, {self(), make_ref()}, state)

      assert_receive {:board_state, {_frame_number, %{board_state: board_state, dimensions: _}}}
      assert board_state |> Map.get({1, 2}) |> Map.has_key?(@player)
    end
  end
end
