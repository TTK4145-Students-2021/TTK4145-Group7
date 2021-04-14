import Config


config :elevator_project,
    #System settings
    number_of_elevators: 3, #Changes on runtime, this is a dummy variable, 1-indexed
    top_floor: 3,   #Floors are 0-indexed

    #Elevator settings
    elevator_number: 1, #Changes on runtime, this is a dummy variable, 1-indexed
    door_timer_interval: 2_000,

    #Order settings
    stop_cost: 1,
    travel_cost: 1,
<<<<<<< HEAD
    check_for_orders_interval: 100,
=======
    multi_call_timeout: 1_000,
    initialization_time: 1_000,
>>>>>>> 22ebf795bb0d13c94cd4a8686253bd426c872cb9

    #Watchdog settings
    order_timeout: 10_000,

    #IO
    polling_interval: 100,
    lights_update_interval: 100

config :logger,
    level: :info
