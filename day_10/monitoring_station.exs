defmodule MonitoringStation do
  def run([path]) do
    path
    |> read_map
    |> find_best_location
    |> show_count
  end
  def run(["-2", path]) do
    asteroids = read_map(path)
    {station, _count} = find_best_location(asteroids)
    asteroids
    |> order_targets(station)
    |> settle_bet
  end

  defp read_map(path) do
    path
    |> File.stream!
    |> Enum.with_index
    |> Enum.flat_map(fn {line, y} ->
      line
      |> String.trim
      |> String.graphemes
      |> Enum.with_index
      |> Enum.filter(fn {"#", _x} -> true; _non_asteroid -> false end)
      |> Enum.map(fn {"#", x} -> {x, y} end)
    end)
    |> MapSet.new
  end

  defp find_best_location(asteroids) do
    asteroids
    |> Enum.map(fn xy ->
      {
        xy,
        asteroids
        |> MapSet.delete(xy)
        |> count_in_line_of_sight(xy)
      }
    end)
    |> Enum.max_by(fn {_xy, count} -> count end)
  end

  defp count_in_line_of_sight(asteroids, reference_point) do
    asteroids
    |> Enum.map(fn xy -> to_polar_coordinates(reference_point, xy) end)
    |> Enum.uniq_by(fn {_r, theta} -> theta end)
    |> length
  end

  defp to_polar_coordinates({reference_x, reference_y}, {x, y}) do
    {adjusted_x, adjusted_y} = {x - reference_x, y - reference_y}
    r = :math.sqrt(:math.pow(adjusted_x, 2) + :math.pow(adjusted_y, 2))
    theta = :math.atan2(adjusted_y, adjusted_x)
    {r, theta}
  end

  defp order_targets(asteroids, station) do
    asteroids
    |> MapSet.delete(station)
    |> Enum.map(fn asteroid ->
      {asteroid, to_adjusted_polar_coordinates(station, asteroid)}
    end)
    |> Enum.group_by(fn {_xy, {_r, theta}} -> theta end)
    |> Enum.into(Map.new, fn {theta, asteroids} ->
      {
        theta,
        asteroids
        |> Enum.sort_by(fn {_xy, {r, _theta}} -> r end)
        |> Enum.map(fn {xy, _polar_coordinates} -> xy end)
      }
    end)
    |> flatten_order
  end

  defp to_adjusted_polar_coordinates(reference_point, xy) do
    {r, theta} = to_polar_coordinates(reference_point, xy)
    adjusted_theta =
      if theta < -:math.pi / 2 do
        (2 * :math.pi) + theta
      else
        theta
      end
    {r, adjusted_theta}
  end

  defp flatten_order(asteroids_by_angle, targets \\ [ ])
  defp flatten_order(asteroids_by_angle, targets)
  when map_size(asteroids_by_angle) == 0 do
    Enum.reverse(targets)
  end
  defp flatten_order(asteroids_by_angle, targets) do
    {new_asteroids_by_angle, new_targets} =
      asteroids_by_angle
      |> Map.keys
      |> Enum.sort
      |> Enum.reduce({asteroids_by_angle, targets}, fn angle, {aoa, t} ->
        case Map.fetch!(aoa, angle) do
          [xy] ->
            {Map.delete(aoa, angle), [xy | t]}
          [xy | rest] ->
            {Map.update!(aoa, angle, fn _asteroids -> rest end), [xy | t]}
        end
      end)
    flatten_order(new_asteroids_by_angle, new_targets)
  end

  defp settle_bet(targets) do
    {x, y} =
      targets
      |> Enum.drop(199)
      |> hd
    IO.puts x * 100 + y
  end

  defp show_count(best) do
    best
    |> elem(1)
    |> IO.puts
  end
end

System.argv
|> MonitoringStation.run
