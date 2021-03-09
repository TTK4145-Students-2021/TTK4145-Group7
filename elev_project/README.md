# ElevProject

Program for controlling `m` elevators over `n` floors.

## How to run

Run the following commands
```
iex -S mix
```
```
ElevProject.Supervisor.start_link
```


## To do

- [x] IO-Poller
- [x] Merge the IO poller and FSM
- [x] State machine of the elevator
- [ ] Implement cost function
- [ ] Implement order 
- [ ] Implement watchdog

## Installation as finished module

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `elev_project` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elev_project, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/elev_project](https://hexdocs.pm/elev_project).

