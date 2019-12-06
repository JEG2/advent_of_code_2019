defmodule UniversalOrbitMap do
  def run([path]) do
    path
    |> read_map(:unidirectional)
    |> compute_checksum
    |> IO.inspect()
  end

  def run(["-2", path]) do
    path
    |> read_map(:bidirectional)
    |> find_route
    |> IO.inspect()
  end

  def read_map(path, edges) do
    map = :digraph.new()

    path
    |> File.stream!()
    |> Enum.each(fn line ->
      [orbited, orbiter] =
        line
        |> String.trim()
        |> String.split(")")

      :digraph.add_vertex(map, orbited)
      :digraph.add_vertex(map, orbiter)

      if edges == :bidirectional do
        :digraph.add_edge(map, orbited, orbiter)
      end

      :digraph.add_edge(map, orbiter, orbited)
    end)

    map
  end

  def compute_checksum(map) do
    map
    |> :digraph.vertices()
    |> Enum.reduce(0, fn vertex, orbits ->
      [vertex]
      |> :digraph_utils.reachable(map)
      |> length
      |> Kernel.-(1)
      |> Kernel.+(orbits)
    end)
  end

  def find_route(map) do
    map
    |> :digraph.get_short_path("YOU", "SAN")
    |> length
    |> Kernel.-(3)
  end

  def show_result(result), do: IO.puts(result)
end

System.argv()
|> UniversalOrbitMap.run()
