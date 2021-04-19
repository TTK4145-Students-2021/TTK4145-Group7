# Elevator Project
Cross platform program for controlling `m` elevators over `n` floors, written in Elixir.

## Program flow
```
Boot node
Ping other Nodes
IO_poller polls sensors and buttons

Button pushed?
  IO sends to the order module.
  Order auctions the order, all the elevators respond with their cost.
  Order accepted (for hall_up/hall_down one other elevator responds)?
    Send the order to the watchdogs.
    Update order_map with the corresponding elevator & order that won the auction.

Finished an order?
  Send a message to all order modules that you finished it.

Order in order_map?
  Calculate the cheapest order and send to elevator.

Order timed out?
  WatchDog sends the order back to auction.
```

## Modules
Quick overview of existing modules and what they do.

##### Order
The brain of the elevator, sends orders to auction, updates the order map/sends orders to the watchdog, takes in new orders from IO and sends the next order to the elevator.

##### WatchDog
Used to handle orders that were not taken in time, sends these back to the Order module for redistribution.

##### Network
Keeps the elevator on the network by pinging the other elevators(if not in single elevator mode).

##### Lights
Retrieves the order map, and updates the lights accordingly.

##### Elevator
State machine for controlling the elevator. Is given a floor, and stops upon reaching that floor.

##### IO_poller
Polls the hardware buttons of the Driver module, and sends these to Elevator and Order accordingly.

##### Driver
For interfacing with the Simulator/elevator at the lab.

## Supervision
All of these modules are implemented under the `Main` application, which starts the supervision tree in `ElevProject.Supervisor`. 


## How to run 
**IMPORTANT** Assumes that you have both elixir and mix installed on your computer.

The entry point to the program is the `elev_project/lib/main.ex` file, or the `elev_project/elevator_run.sh` bash script.
To change config parameters go to `elev_project/config/config.exs`. 

**IMPORTANT** the network config needs to be changed based on IP, as we manually add them to the list of `node_ips` in `elev_project/config/config.exs`. Here the format is `:"<elevator_number>@<node_ip>"`, which predetermines what IP is what elevator number. As long as one of the elevators have the correct IPs in its config it should work, due to elixir's Node module.

Navigate to the `elev_project` folder and run the following to get the dependencies.
```
mix deps.get
```

### Run using the script (Linux only)

#### Install tmux
On ubuntu
```
sudo apt install tmux
```

#### Run the script
If you have tmux installed you can run the `elevator_run.sh` script.

To navigate the tmux windows visit [tmux-cheat-sheet](https://tmuxcheatsheet.com/), to enable mouse clicking create ~/.tmux.conf and add the line `set-window-option -g mouse on`

With 1,2 or 3 `total_number_of_elevators`.`
Navigate to the `elevator_run_sh` script.
```
./elevator_run.sh <total_number_of_elevators>
```

### Run using commands

First you need to run the simulators, these can be found in the simulator folder.
Navigate to the `Simulator` folder.
The simulator port has to match the elevator port. 6000, 6001, 6002 are examples of usable ports.

*On Linux:*
```
./SimElevatorServer --port <port>
```
*On Windows:*
```
SimElevatorServer.exe -port <port>
```

Then the elevators can seperately be started with the following commands from within the `elev_project` folder.
Here the `elevator_number` starts at 1. The second elevator you start has the number 2 and so on. The `total_number_of_elevators` are 1-indexed as well.

Navigate to the `elev_project` folder.

On Linux/Windows:
```
iex -S mix
Main.run_elevator <port>, <elevator_number>, <total_number_of_elevators>
```

If it is not already running, start the Erlang port mapper daemon:
*On Linux:*
```
epmd -daemon
```
*On Windows, you need to locate epmd.exe and run it:*

```
epmd.exe -daemon
```

## Credits

GenStateMachine is used for FSM in the elevator.

Inspiration from Jostein Løwer's [kokeplata](https://github.com/jostlowe/kokeplata) in Network and IO_poller. And also for his Driver module.