defmodule MMO.GameTest do
  use ExUnit.Case, async: true
  doctest MMO.Game

  alias MMO.{Game, GameState}

  @player "me"

  setup do
    {:ok, game_state} = GameState.new()

    %{game_state: game_state}
  end

  defp player_in?(%GameState{player_info: player_info}, player, coord) do
    assert get_in(player_info, [player, :position]) == coord
  end

  defp player_info(coalesced_board, player) do
    {coord, contents} =
      Enum.find(coalesced_board, fn
        {_coord, cell} when is_atom(cell) -> false
        {_coord, contents} -> Map.has_key?(contents, player)
      end)

    %{position: coord, status: Map.get(contents, player)}
  end

  describe "move" do
    setup %{game_state: game_state} do
      {:ok, game_state} = GameState.spawn_player_at(game_state, @player, {1, 1})
      {:ok, state} = Game.State.new(game_state)

      %{state: state}
    end

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

  test "player respawn", %{game_state: game_state} do
    {:ok, game_state} = GameState.spawn_player_at(game_state, @player, {1, 1})
    {:ok, game_state} = GameState.spawn_player_at(game_state, "other", {1, 2})
    {:ok, state} = Game.State.new(game_state)

    # we need to actually start the GenServer instance here, because the respawn functionality
    # relies on `Process.send_after/4` to delay the respawning: if we simply called the callback
    # directly, the respawn command message would simply be sent to this testing process and nothing
    # (i.e. no respawn) would happen.
    game = start_supervised!({Game, state: state})

    :ok = Game.attack(game, @player)

    assert_receive {:board_state, {_frame_number, %{board_state: board_state, dimensions: _}}}
    assert :dead = board_state |> Map.get({1, 2}) |> Map.get("other")
    assert %{status: :dead} = player_info(board_state, "other")

    assert_receive {:board_state, {_frame_number, %{board_state: board_state, dimensions: _}}},
                   500

    assert %{status: :alive} = player_info(board_state, "other")
  end
end
