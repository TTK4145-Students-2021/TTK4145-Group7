# Elevator Project

Program for controlling `m` elevators over `n` floors, written in Elixir.

## Program flow
```
Boot node
Ping other Nodes
IO_poller polls sensors and buttons

Button pushed?
  IO sends to the order module.
  Order auctions the order, calculating its cost.
  Order accepted (for hall_up/hall_down one other elevator responds)?
    Send the order to the watchdogs.
    Update order_map with the elevator that won the auction.

Order in order_map?
  Calculate the cheapest order and send to elevator.

Order timed out?
  WatchDog sends the order back to auction.
```

## Modules

These are the following modules we have in our elevator
##### Order
The brain of the elevator, sends orders to auction, updates the order map, takes in new orders from IO and sends the next order to the elevator.

##### WatchDog
Used to handle orders that were not taken in time, sends these back to the Order module.

##### Network
Keeps the elevator on the network by pinging the other elevators(if not in single elevator mode)

##### Lights
Retrieves the order map, and updates the lights accordingly

##### Elevator
State machine for controlling the elevator, is given a floor, and goes to that floor.

##### IO_poller
Polls the hardware buttons of the Driver module, and sends these accordingly to Elevator and Order.

##### Driver
For interfacing with the Simulator/elevator at the lab

## Supervision
All of these modules are implemented under the `Main` application, which starts the supervision tree in `ElevProject.Supervisor`.


## How to run
The entry point to the program is the `elev_project/lib/main.ex` file, or the `elev_project/elevator_run.sh` bash script.
To change config parameters go to `elev_project/config/config.exs`. **IMPORTANT** the network config needs to be changed based on IP, as we manually add them to the list of `node_ips` in `config.exs`.

### Run using the script

### Install tmux
On ubuntu
```
sudo apt install tmux
```

### Run the script
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
```
./SimElevatorServer --port <port>
```

Then the elevators can seperately be started with the following commands from within the `elev_project` folder.
The simulator port has to match the elevator port. 6000, 60001, 6002 are examples of usable ports.
Here the elevator_number starts at 1. The second elevator you start has the number 2 and so on. The total number of elevators are 1-indexed as well.

Navigate to the `elev_project` folder.
```
iex -S mix
Main.start <port>, <elevator_number>, <total_number_of_elevators>
```