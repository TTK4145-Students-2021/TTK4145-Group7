import Config


config :elevator_project,
    #System settings
    number_of_elevators: 3, #Changes on runtime, this is dummy variable, 1-indexed
    top_floor: 3,   # Floors are 0-indexed
    
    #Elevator settings
    door_timer_interval: 2_000,

    #Order settings
    stop_cost: 1,
    travel_cost: 1,

    #Watchdog settings
    order_timeout: 10_000
