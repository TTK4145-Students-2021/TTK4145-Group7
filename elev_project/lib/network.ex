defmodule Network do
  @moduledoc """
  Network module used to connect and keep the connection to the other elevators.
  """
  use Task
  require Logger

  @ping_interval Application.fetch_env!(:elevator_project, :ping_interval) 
  @node_ips      Application.fetch_env!(:elevator_project, :node_ips)
  
  @doc """
  Start the network module.
  """
  def start_link([]) do
      Task.start_link(__MODULE__, :ping_nodes, [])
  end

  @doc """
  Pings all the other elevator nodes. Keeps the nodes connected when it is possible.
  """
  def ping_nodes(connected_nodes \\ 1) do 
    Process.sleep(@ping_interval)

    node_answers = 
      @node_ips
      |> Enum.reduce([], fn node, acc -> acc++[{node, Node.ping(node)}]end)

    alive_nodes = 
      node_answers
      |> Keyword.values()
      |> Enum.count(fn x -> x === :pong end)

    cond do
      connected_nodes < alive_nodes ->
          Logger.info("A node reconnected to elevator network")
          Order.compare_order_maps

      connected_nodes > alive_nodes ->
        Enum.each(node_answers, fn x -> if elem(x,1) === :pang do 
              Logger.warning("Lost connection to " <> to_string(elem(x,0)))
            end
          end)

      true -> 
        nil
    end
  
    ping_nodes(alive_nodes)
  end

  @doc """
    boots node with a given elevator number and ip given from the config file.
  """
  def boot_node(tick_time \\ 7_500) do
    elevator_number = Application.fetch_env!(:elevator_project, :elevator_number)
    full_name = elem(List.to_tuple(@node_ips), elevator_number-1)

    Node.start(full_name, :longnames, tick_time)
    Node.set_cookie(:epicalyx)
  end
end