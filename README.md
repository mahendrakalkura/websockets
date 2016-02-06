# Requirements

- Erlang 7.2 - https://www.erlang.org/
- Elixir 1.2 - http://elixir-lang.org/
- PostgreSQL 9.X - http://www.postgresql.org

# How to install?

## Step 1:

```
$ mkdir websockets
$ cd websockets
$ git clone git@bitbucket.org:tellecast/websockets.git .
$ cp --archive config/config.exs.sample config/config.exs # edit as required
$ mix local.hex
$ mix deps.get
$ mix deps.compile
```

# How to serve?

```
$ cd websockets
$ iex -S mix
```

# How to test?

```
$ cd websockets
$ mix dogma
$ mix credo
$ mix credo --strict
$ mix credo list
$ mix test
```
