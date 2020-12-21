defmodule MMO.GameStateTest do
  use ExUnit.Case, async: true
  doctest MMO.GameState

  alias MMO.GameState
  alias MMO.Actions.{Attack, Move}

  defp render_state(state) do
    GameState.render(state, "me")
  end

  defp assert_action(state, pre, action, post) do
    assert render_state(state) == pre
    {_result, state} = GameState.apply_action(state, action)
    assert render_state(state) == post
  end

  describe "player movement" do
    setup do
      {:ok, state} = GameState.new()
      {:ok, state} = GameState.spawn_player_at(state, "me", {1, 1})

      %{state: state}
    end

    test "can move to neighboring walkable cell", %{state: state} do
      assert_action(
        state,
        """
        ##########
        #@       #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """,
        Move.new("me", {1, 2}),
        """
        ##########
        # @      #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """
      )
    end

    test "cannot move diagonally", %{state: state} do
      assert_action(
        state,
        """
        ##########
        #@       #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """,
        Move.new("me", {2, 2}),
        """
        ##########
        #@       #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """
      )
    end

    test "cannot move into wall", %{state: state} do
      assert_action(
        state,
        """
        ##########
        #@       #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """,
        Move.new("me", {1, 0}),
        """
        ##########
        #@       #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """
      )
    end

    test "cannot move more than 1 cell", %{state: state} do
      assert_action(
        state,
        """
        ##########
        #@       #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """,
        Move.new("me", {1, 3}),
        """
        ##########
        #@       #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """
      )
    end

    test "can move onto a cell containing another player", %{state: state} do
      {:ok, state} = GameState.spawn_player_at(state, "other_player", {1, 2})

      assert_action(
        state,
        """
        ##########
        #@1      #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """,
        Move.new("me", {1, 2}),
        """
        ##########
        # @      #
        #        #
        #        #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #        #
        ##########
        """
      )

      {_result, state} = GameState.apply_action(state, Move.new("me", {1, 2}))

      players_on_cell =
        state
        |> GameState.coalesce()
        |> Map.get({1, 2})

      assert Map.has_key?(players_on_cell, "me")
      assert Map.has_key?(players_on_cell, "other_player")
      assert Enum.count(players_on_cell) == 2
    end
  end

  describe "player attack" do
    setup do
      {:ok, state} = GameState.new()

      player_locations = [
        {"me", {2, 3}},
        {"a", {1, 2}},
        {"b", {1, 2}},
        {"c", {2, 2}},
        {"d", {2, 3}},
        {"e", {3, 2}},
        {"f", {3, 2}},
        {"g", {3, 3}},
        {"z1", {1, 4}},
        {"z2", {1, 4}},
        {"z3", {1, 4}},
        {"z4", {1, 4}},
        {"z5", {1, 4}},
        {"z6", {1, 4}},
        {"z7", {1, 4}},
        {"z8", {1, 4}},
        {"z9", {1, 4}},
        {"z10", {1, 4}},
        {"out_of_reach_1", {2, 5}},
        {"out_of_reach_2", {8, 7}}
      ]

      state =
        Enum.reduce(player_locations, state, fn {player, location}, state ->
          {:ok, state} = GameState.spawn_player_at(state, player, location)
          state
        end)

      %{state: state}
    end

    test "attacking kills all surrounding players, but no others", %{state: state} do
      assert_action(
        state,
        """
        ##########
        # 2 *    #
        # 1@ 1   #
        # 21     #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #      1 #
        ##########
        """,
        Attack.new("me"),
        """
        ##########
        # x x    #
        # x@ 1   #
        # xx     #
        ## ####  #
        #   #    #
        #   #    #
        #   #    #
        #      1 #
        ##########
        """
      )
    end

    test "attacking kills enemies on the same cell as the hero, but not the hero himself", %{
      state: state
    } do
      {_, state} = GameState.apply_action(state, Attack.new("me"))

      {alive, dead} =
        state
        |> GameState.coalesce()
        |> Map.get({2, 3})
        |> Enum.split_with(fn {_player, status} -> status == :alive end)

      assert [{"me", :alive}] = alive
      assert Enum.count(dead) > 0
    end
  end

  test "new/1 returns an error if the board is too big" do
    {:ok, board} =
      MMO.Board.new("""
      ######
      #    #
      # ####
      #    #
      #    #
      #    #
      ######
      """)

    assert {:ok, _} = GameState.new(max_board_dimension: 7, board: board)

    assert {:error, :max_board_dimension_exceeded} =
             GameState.new(max_board_dimension: 6, board: board)

    assert {:error, {:invalid_option, :max_board_dimension}} =
             GameState.new(max_board_dimension: -1, board: board)
  end

  test "a maximum player count is enforced if provided" do
    assert {:error, {:invalid_option, :max_players}} = GameState.new(max_players: 1)

    {:ok, state} = GameState.new(max_players: 2)
    {:ok, state} = GameState.spawn_player(state, "foo")
    {:ok, state} = GameState.spawn_player(state, "bar")
    assert {{:error, :max_players}, _} = GameState.spawn_player(state, "baz")
  end
end
