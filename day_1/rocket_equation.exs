defmodule RocketEquation do
  def run([path]), do: process(path, &mass_to_fuel/1)
  def run(["-2", path]), do: process(path, &mass_to_fuel_recursive/1)

  def process(path, converter) do
    path
    |> read_input
    |> convert_mass_to_fuel(converter)
    |> total_fuel_cost
    |> show_result
  end

  def read_input(path) do
    path
    |> File.stream!
    |> Stream.map(fn line ->
      line
      |> String.trim
      |> String.to_integer
    end)
  end

  def convert_mass_to_fuel(masses, converter), do: Stream.map(masses, converter)

  def total_fuel_cost(fuel_costs), do: Enum.sum(fuel_costs)

  def show_result(result), do: IO.puts result

  defp mass_to_fuel(mass), do: div(mass, 3) - 2

  defp mass_to_fuel_recursive(mass, total \\ 0)
  defp mass_to_fuel_recursive(mass, total) when mass <= 0, do: total - mass
  defp mass_to_fuel_recursive(mass, total) do
    fuel = mass_to_fuel(mass)
    mass_to_fuel_recursive(fuel, total + fuel)
  end
end

System.argv
|> RocketEquation.run
