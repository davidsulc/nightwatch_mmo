defmodule MMOTest do
  use ExUnit.Case
  doctest MMO

  test "greets the world" do
    assert MMO.hello() == :world
  end
end
