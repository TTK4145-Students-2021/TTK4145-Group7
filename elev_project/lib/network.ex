defmodule Network do
  @moduledoc """
  Network module used to connect and keep the connection to the other elevators.
  """
  
  use Task
  
  def start_link([]) do
      Task.start_link(__MODULE__, :ping_nodes, [])
  end

  @doc """
  Gets a list of all the elevator node names in the system.
  """
  def get_all_nodes() do
    n_elevators = Application.fetch_env!(:elevator_project, :number_of_elevators)
    Enum.map(1..n_elevators, fn x -> String.to_atom(to_string(x) <> "@" <> to_string(:inet.ntoa(get_my_ip()))) end)
  end

  @doc """
  Pings all the other elevator nodes every seconds, keeps the nodes connected, when they can.
  """
  def ping_nodes(connected_nodes \\ 1) do 
      answer = Enum.reduce(get_all_nodes(), [], fn node, acc -> acc++[{node, Node.ping(node)}]end)
      Process.sleep(1_000)
      alive_nodes = Enum.count(Keyword.values(answer), fn x -> x === :pong end)

      if connected_nodes === 1 and alive_nodes !== 1 do
          IO.puts("BACK ONLINE BABY")
          Order.compare_order_states
      end

      ping_nodes(alive_nodes)
  end

  def get_my_ip do
    {:ok, [{ip, _, _}, _]} = :inet.getif
    ip
  end

  @doc """
  Returns all nodes in the current cluster. Returns a list of nodes or an error message
  ## Examples
      iex> Network.all_nodes
      [:'heis@10.100.23.253', :'heis@10.100.23.226']
      iex> Network.all_nodes
      {:error, :node_not_running}
  """
  def all_nodes do
    case [Node.self | Node.list] do
      [:'nonode@nohost'] -> {:error, :node_not_running}
      nodes -> nodes
    end
  end

  @doc """
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
end