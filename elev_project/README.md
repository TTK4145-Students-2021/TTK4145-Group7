# ElevProject

Program for controlling `m` elevators over `n` floors.

## How to run

Run the following commands
```
iex --sname "name" -S mix
```
```
ElevProject.Supervisor.start_link("port", "elevator_number")
```


## To do

- [x] IO-Poller
- [x] Merge the IO poller and FSM
- [x] State machine of the elevator
- [x] Finish light module
- [x] Implement cost function
- [x] Test cost function
- [x] Implement getting the next order from order_map using cost function?
- [x] Implement watchdog
- [x] Finish elevator logic


## Errors

- [x] Lights flicker when watchdog times out, especially during packet loss.

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

