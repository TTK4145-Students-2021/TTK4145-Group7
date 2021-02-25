defmodule Driver do
  use GenServer
  @call_timeout 1000
  @button_map %{:hall_up => 0, :hall_down => 1, :cab => 2}
  @state_map  %{:on => 1, :off => 0}
  @direction_map %{:up => 1, :down => 255, :stop => 0}

  def start_link([]) do
    start_link [{127,0,0,1}, 15657]
  end

  def start_link([address, port]) do
    GenServer.start_link(__MODULE__, [address, port], name: __MODULE__)
  end

  def stop do
    GenServer.stop __MODULE__
  end

  def init [address, port] do
    {:ok, socket} =:gen_tcp.connect(address, port, [{:active, false}])
    {:ok, socket}
  end


  # User API ----------------------------------------------
  # direction can be :up/:down/:stop
  def set_motor_direction direction do
    GenServer.cast __MODULE__, {:set_motor_direction, direction}
  end

  # button_type can be :hall_up/:hall_down/:cab
  # state can be :on/:off
  def set_order_button_light button_type, floor, state do
    GenServer.cast __MODULE__, {:set_order_button_light, button_type, floor, state}
  end

  def set_floor_indicator floor do
    GenServer.cast __MODULE__, {:set_floor_indicator, floor}
  end

  # state can be :on/:off
  def set_stop_button_light state do
    GenServer.cast __MODULE__, {:set_stop_button_light, state}
  end

  # state can be :on/:off
  def set_door_open_light state do
    GenServer.cast __MODULE__, {:set_door_open_light, state}
  end

  def get_order_button_state floor, button_type do
    GenServer.call __MODULE__, {:get_order_button_state, floor, button_type}
  end

  def get_floor_sensor_state do
    GenServer.call __MODULE__, :get_floor_sensor_state
  end

  def get_stop_button_state do
    GenServer.call __MODULE__, :get_stop_button_state
  end

  def get_obstruction_switch_state do
    GenServer.call __MODULE__, :get_obstruction_switch_state
  end



  # Casts  ----------------------------------------------
  def handle_cast {:set_motor_direction, direction}, socket do
    :gen_tcp.send(socket, [1, @direction_map[direction], 0, 0])
    {:noreply, socket}
  end

  def handle_cast {:set_order_button_light, button_type, floor, state}, socket do
    :gen_tcp.send socket, [2, @button_map[button_type], floor, @state_map[state]]
    {:noreply, socket}
  end

  def handle_cast {:set_floor_indicator, floor}, socket do
    :gen_tcp.send socket, [3, floor, 0, 0]
    {:noreply, socket}
  end

  def handle_cast {:set_door_open_light, state}, socket do
    :gen_tcp.send socket, [4, @state_map[state], 0, 0]
    {:noreply, socket}
  end

  def handle_cast {:set_stop_button_light, state}, socket do
    :gen_tcp.send socket, [5, @state_map[state], 0, 0]
    {:noreply, socket}
  end



  # Calls  ----------------------------------------------
  def handle_call {:get_order_button_state, floor, order_type}, _from, socket do
    :gen_tcp.send socket, [6, @button_map[order_type], floor, 0]
    {:ok, [6, state, 0, 0]} = :gen_tcp.recv(socket, 4, @call_timeout)
    {:reply, state, socket}
  end


  def handle_call :get_floor_sensor_state, _from, socket do
    :gen_tcp.send socket, [7, 0, 0, 0] 
    button_state = case :gen_tcp.recv(socket, 4, @call_timeout) do
      {:ok, [7, 0, _, 0]} -> :between_floors
      {:ok, [7, 1, floor, 0]} -> floor
    end
    {:reply, button_state, socket}
  end

  def handle_call :get_stop_button_state, _from, socket do
    :gen_tcp.send socket, [8, 0, 0, 0] 
    button_state = case :gen_tcp.recv(socket, 4, @call_timeout) do
      {:ok, [8, 0, 0, 0]} -> :inactive
      {:ok, [8, 1, 0, 0]} -> :active
    end
    {:reply, button_state, socket}
  end

  def handle_call :get_obstruction_switch_state, _from, socket do
    :gen_tcp.send socket, [9, 0, 0, 0] 
    button_state = case :gen_tcp.recv(socket, 4, @call_timeout) do
      {:ok, [9, 0, 0, 0]} -> :inactive
      {:ok, [9, 1, 0, 0]} -> :active
    end
    {:reply, button_state, socket}
  end
end
