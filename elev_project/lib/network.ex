defmodule Network do
  @moduledoc """
  Network module used to connect and keep the connection to the other elevators.
  """

  use Task
  require Logger

  @ping_interval Application.fetch_env!(:elevator_project, :ping_interval) 
  
  def start_link([]) do
      Task.start_link(__MODULE__, :ping_nodes, [])
  end

  @doc """
  Pings all the other elevator nodes every seconds, keeps the nodes connected, when they can.
  """
  def ping_nodes(connected_nodes \\ 1) do 
    Process.sleep(@ping_interval)

    node_answers = 
      get_all_nodes()
      |> Enum.reduce([], fn node, acc -> acc++[{node, Node.ping(node)}]end)

    alive_nodes = 
      node_answers
      |> Keyword.values()
      |> Enum.count(fn x -> x === :pong end)

    cond do
      connected_nodes === 1 and alive_nodes > 1 ->
          Logger.info("A node reconnected to elevator network")
          Order.compare_order_states

      connected_nodes > alive_nodes ->
        Enum.each(node_answers, fn x -> if elem(x,1) === :pang do 
              Logger.warning("Lost connection to " <> to_string(elem(x,0)))
            end
          end)
      true -> nil
    end
  
    ping_nodes(alive_nodes)
  end

  @doc """
  Template from Jostein Løwer
  boots a node with a specified tick time. node_name sets the node name before @. The IP-address is
  automatically imported
      iex> Network.boot_node "frank"
      {:ok, #PID<0.12.2>}
      iex(frank@10.100.23.253)> 
  """
  def boot_node(node_name, tick_time \\ 15000) do
    ip = get_my_ip() |> :inet.ntoa() |> to_string()
    full_name = node_name <> "@" <> ip
    Node.start(String.to_atom(full_name), :longnames, tick_time)
    Node.set_cookie(:epicalyx)
  end

  def get_my_ip do
    {:ok, [{ip, _, _}, _]} = :inet.getif
    ip
  end

  @doc """
  Gets a list of all the elevator node names in the system.
  """
  def get_all_nodes() do
    n_elevators = Application.fetch_env!(:elevator_project, :number_of_elevators)
    Enum.map(1..n_elevators, fn x -> String.to_atom(to_string(x) <> "@" <> to_string(:inet.ntoa(get_my_ip()))) end)
  end
end