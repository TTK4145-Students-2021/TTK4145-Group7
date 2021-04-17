import Config


config :elevator_project,
    #System settings
    number_of_elevators: 3, #Changes on runtime, this is a dummy variable, 1-indexed
    top_floor: 3,   #Floors are 0-indexed

    #Elevator settings
    elevator_number: 1, #Changes on runtime, this is a dummy variable, 1-indexed
    door_timer_interval: 2_000,

    #Order settings
    stop_cost: 2,
    travel_cost: 3,
    order_penalty: 10,
    multi_call_timeout: 500,
    initialization_time: 1_000,
    check_for_orders_interval: 100,

    #Watchdog settings
    order_timeout: 12_250,

    #IO
    polling_interval: 100,
    lights_update_interval: 100,

    #Network
    ping_interval: 1000,
    node_ips: [:"1@192.168.1.55", :"2@192.168.1.56", :"3@192.168.1.57"]

config :logger,
    level: :info
