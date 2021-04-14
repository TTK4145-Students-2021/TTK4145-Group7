import Config


config :elevator_project,
    number_of_elevators: 3, #Changes on runtime, this is dummy variable
    top_floor: 3,

    door_timer_interval: 2_000,
    stop_cost: 1,
    travel_cost: 1,

    order_timeout: 10_000
