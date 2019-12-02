defmodule Intcode do
  def run([path]) do
    path
    |> parse_program
    |> reset_to_error
    |> execute_program
    |> show_result
  end
  def run(["-2", path]) do
    path
    |> parse_program
    |> correct_error
    |> show_result
  end

  def parse_program(path) do
    path
    |> File.read!
    |> String.trim
    |> String.split(",")
    |> Enum.map(&String.to_integer/1)
    |> Enum.with_index
    |> Enum.into(Map.new, fn {n, i} -> {i, n} end)
  end

  def reset_to_error(program, noun \\ 12, verb \\ 2) do
    program
    |> Map.put(1, noun)
    |> Map.put(2, verb)
  end

  def execute_program(program, instruction_pointer \\ 0) do
    case Map.fetch!(program, instruction_pointer) do
      1 ->
        program
        |> execute_opcode(instruction_pointer, &Kernel.+/2)
        |> execute_program(instruction_pointer + 4)
      2 ->
        program
        |> execute_opcode(instruction_pointer, &Kernel.*/2)
        |> execute_program(instruction_pointer + 4)
      99 ->
        program
    end
  end

  defp execute_opcode(program, instruction_pointer, operation) do
    Map.put(
      program,
      Map.fetch!(program, instruction_pointer + 3),
      operation.(
        lookup(program, instruction_pointer + 1),
        lookup(program, instruction_pointer + 2)
      )
    )
  end

  defp lookup(program, address_location) do
    Map.fetch!(program, Map.fetch!(program, address_location))
  end

  def correct_error(program) do
    for noun <- 0..99, verb <- 0..99 do {noun, verb} end
    |> Enum.find(fn {noun, verb} ->
      program
      |> reset_to_error(noun, verb)
      |> execute_program
      |> check_result
    end)
  end

  defp check_result(%{0 => 19690720}), do: true
  defp check_result(_program), do: false

  def show_result(program) when is_map(program) do
    program
    |> Map.fetch!(0)
    |> IO.puts
  end
  def show_result({noun, verb}), do: IO.puts 100 * noun + verb
end

System.argv
|> Intcode.run
