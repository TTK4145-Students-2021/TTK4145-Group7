import Config


config :elevator_project,
    number_of_elevators: 3,
    top_floor: 3,

    door_timer_interval: 2_000,
    stop_cost: 1,
    travel_cost: 1

import_config "#{config_env()}.exs"