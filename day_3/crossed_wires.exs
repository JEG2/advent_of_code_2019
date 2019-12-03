defmodule CrossedWires do
  def run([path]) do
    path
    |> trace_wires
    |> find_intersections
    |> find_closest_to_port
    |> show_closest
  end
  def run(["-2", path]) do
    path
    |> trace_wires
    |> add_intersections
    |> find_closest_by_steps
    |> show_closest
  end

  def trace_wires(path) do
    path
    |> File.stream!
    |> Stream.map(fn line ->
      line
      |> String.trim
      |> String.split(",")
    end)
    |> Stream.map(fn directions ->
      directions
      |> Stream.map(&parse_segment/1)
      |> Enum.reduce([{0, 0}], &add_points/2)
    end)
    |> Stream.map(fn points ->
      points
      |> Enum.reverse
      |> tl
    end)
  end

  defp parse_segment(segment) do
    %{
      "direction" => direction,
      "distance" => distance
    } = Regex.named_captures(
      ~r{\A(?<direction>[UDLR])(?<distance>\d+)\z},
      segment
    )
    offset =
      case direction do
        "U" -> {0, -1}
        "D" -> {0, 1}
        "L" -> {-1, 0}
        "R" -> {1, 0}
      end
    %{offset: offset, distance: String.to_integer(distance)}
  end

  defp add_points(
    %{offset: {offset_x, offset_y}, distance: distance},
    points
  ) do
    points
    |> Stream.iterate(fn [{prev_x, prev_y} = prev | rest] ->
      [{prev_x + offset_x, prev_y + offset_y}, prev | rest]
    end)
    |> Stream.drop(1)
    |> Stream.take(distance)
    |> Enum.at(-1)
  end

  def find_intersections(wires) do
    wires
    |> Stream.map(&MapSet.new/1)
    |> Enum.reduce(&MapSet.intersection/2)
    |> MapSet.delete({0, 0})
  end

  def add_intersections(wires) do
    %{wires: wires, intersections: find_intersections(wires)}
  end

  def find_closest_to_port(intersections) do
    intersections
    |> Stream.map(fn {x, y} -> abs(x) + abs(y) end)
    |> Enum.min
  end

  def find_closest_by_steps(map) do
    map.intersections
    |> Stream.map(fn intersection ->
      Enum.reduce(map.wires, 0, fn wire, sum ->
        sum + Enum.find_index(wire, fn point -> point == intersection end) + 1
      end)
    end)
    |> Enum.min
  end

  def show_closest(closest) do
    IO.puts closest
  end
end

System.argv
|> CrossedWires.run
