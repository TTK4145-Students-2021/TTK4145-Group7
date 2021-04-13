#!/bin/bash
start_simulator () {
    tmux send-keys "cd .." Enter
    tmux send-keys "cd Simulator" Enter
    tmux send-keys "./SimElevatorServer --port $1" Enter
}

start_elevator () {
    tmux send-keys "iex -S mix" Enter
    tmux send-keys "Main.start $1, $2, $3" Enter
}

case $1 in
    1)
    echo "Starting 1 elevator"
    tmux new -d -s "elev"

    tmux split-window -h
    start_simulator "6000"

    tmux select-pane -t 0
    start_elevator "6000" "1" "1"

    tmux select-pane -t 1

    tmux attach
    ;;
    2)
    echo "Starting 2 elevators"

    tmux new -d -s "elev"
    tmux split-window -h
    start_simulator "6000"

    tmux split-window -v
    start_simulator "6001"

    tmux select-pane -t 0
    start_elevator "6000" "1" "2"

    tmux split-window -v
    start_elevator "6001" "2" "2"

    tmux select-pane -t 2

    tmux attach

    ;;
    3)
    echo "Starting 3 elevators"
    tmux new -d -s "elev"
    
    tmux split-window -h
    start_simulator "6000"

    tmux split-window -v -p 66
    start_simulator "6001"

    tmux split-window -v
    start_simulator "6002"
    
    tmux select-pane -t 0
    start_elevator "6000" "1" "3"
    
    tmux split-window -v -p 66
    start_elevator "6001" "2" "3"
    
    tmux split-window -v
    start_elevator "6002" "3" "3"

    tmux select-pane -t 3

    tmux attach
    ;;
esac

