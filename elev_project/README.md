# ElevProject

# How to run

Run the following commands
```
iex -S mix
HardwareSupervisor.start_link [3]

```

# To do

- [x] IO-Poller
- [ ] Merge the IO poller and FSM
- [ ] State machine of the elevator
- [ ] Implement cost function

## Installation

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

