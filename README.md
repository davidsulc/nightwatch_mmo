# MMO

<!-- MDOC !-->

`MMO` is a server for a simple Massively Multiplayer Online (MMO) game.

It is designed to be the back-end server, but includes barebones functionality to
play within the console also.

`MMO` is an OTP application with its own supervision tree. However, you may wish to
include `MMO` as a dependency with `runtime: false` in order to leverage its
functionality to interact with a remote `MMO` instance.

To start a "default" game in your supervision tree, simply include

```
{Task, fn -> MMO.new_game("default game") end}
```

among the application supervisor's children to spawn an MMO instance with the
"default game" name during your application's startup.

## Quickstart

Let's take `MMO` out for a spin in the console. (Refer to docs for `MMO.Utils.render/3`
for the meaning behing each rendered symbol.)

```
# start a new game called "game"
iex> MMO.new("game")

## Let's add some players
# Add "Geralt" to the game
iex> {:ok, geralt} = MMO.start_link("game", "Geralt")
# Add a player with a random name to the game
iex> {:ok, other} = MMO.start_link("game")
# Add a player called "me" to the game
iex> {:ok, me} = MMO.start_link("game", "me")

# Let's see what the game currently looks like:
iex> MMO.puts(me)
##########
#        #
#     @  #
#   1    #
## ####  #
# 1 #    #
#   #    #
#   #    #
#        #
##########

## Let's move near a player so we'll be in attack range:
iex> MMO.move(me, :down)
iex> MMO.move(me, :left)
iex> MMO.puts(me)
##########
#        #
#        #
#   1@   #
## ####  #
# 1 #    #
#   #    #
#   #    #
#        #
##########

## Let's attack the other player:
iex> MMO.attack(me)
iex> MMO.puts(me)
##########
#        #
#        #
#   x@   #
## ####  #
# 1 #    #
#   #    #
#   #    #
#        #
##########

## Let's wait 5 seconds, and we can see that the dead player has respawned:
iex> MMO.puts(me)
##########
#        #
#        #
#    @   #
## ####  #
# 1 #   1#
#   #    #
#   #    #
#        #
##########
```

## Demo Setup

An IEx configuration is available, which will spawn a "me" player along with 20 integer-named
other players (from 1 to 20):

```
iex> {me, sessions} = setup_demo.()
##########
#  112   #
#   11 1 #
#   1   1#
## ####1 #
#@  #11  #
#1  #  1 #
# 1 #11 1#
#   1  1 #
##########

iex> MMO.puts(me)
##########
#  112   #
#   11 1 #
#   1   1#
## ####1 #
#@  #11  #
#1  #  1 #
# 1 #11 1#
#   1  1 #
##########

# Show the game from player 7's point of view:
iex> sessions |> Map.get(7) |> MMO.puts()
##########
#  112   #
#   1@ 1 #
#   1   1#
## ####1 #
#1  #11  #
#1  #  1 #
# 1 #11 1#
#   1  1 #
##########
```

<!-- MDOC !-->

## Installation

Include `{:mmo, github: "davidsulc/nightwatch_mmo"}` in your dependencies and run `mix deps.get`.

## Documentation

Build with `mix docs`, then view `doc/index.html` in a web browser.

## Tests

Run `mix test`. Please note the test coverage is only partial.

## Dialyzer

Run `mix dialyzer` to check the project. Although most specs are defined, the coverage is incomplete.

## Release Building

Run `mix release PLATFORM` where `PLATFORM` is one of `unix` or `windows`. Running `mix release` defaults to `mix release unix`.
