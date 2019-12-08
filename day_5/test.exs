defmodule Intcode do
  defstruct program: nil, input: nil, output: "", instruction_pointer: 0

  defp opcodes, do:
    %{
      1 => fn intcode, left, right, result_address ->
        write_to_program(
          intcode,
          to_position(result_address),
          interpret(intcode.program, left) + interpret(intcode.program, right)
        )
      end,
      2 => fn intcode, left, right, result_address ->
        write_to_program(
          intcode,
          to_position(result_address),
          interpret(intcode.program, left) * interpret(intcode.program, right)
        )
      end,
      3 => fn %__MODULE__{input: [current | rest]} = intcode, address ->
        write_to_program(
          %__MODULE__{intcode | input: rest},
          to_position(address),
          current
        )
      end,
      4 => fn intcode, value ->
        output =
          intcode.program
          |> interpret(value)
          |> to_string
        %__MODULE__{intcode | output: intcode.output <> output}
      end,
      5 => fn intcode, condition, location ->
        if interpret(intcode.program, condition) != 0 do
          jump_to(intcode, interpret(intcode.program, location))
        else
          intcode
        end
      end,
      6 => fn intcode, condition, location ->
        if interpret(intcode.program, condition) == 0 do
          jump_to(intcode, interpret(intcode.program, location))
        else
          intcode
        end
      end,
      7 => fn intcode, left, right, result_address ->
        compare(
          intcode,
          to_position(result_address),
          interpret(intcode.program, left) < interpret(intcode.program, right)
        )
      end,
      8 => fn intcode, left, right, result_address ->
        compare(
          intcode,
          to_position(result_address),
          interpret(intcode.program, left) == interpret(intcode.program, right)
        )
      end,
      99 => fn intcode ->
        %__MODULE__{intcode | instruction_pointer: :halt}
      end
    }

  def new(path, input) do
    %__MODULE__{program: parse_program(path), input: input}
  end

  defp parse_program(path) do
    path
    |> File.read!
    |> String.trim
    |> String.split(",")
    |> Enum.map(&String.to_integer/1)
    |> Enum.with_index
    |> Enum.into(Map.new, fn {n, i} -> {i, n} end)
  end

  def execute(intcode) do
    {parameter_modes, opcode} = parse_opcode(intcode)
    operation = Map.fetch!(opcodes(), opcode)
    {:arity, param_count} = Function.info(operation, :arity)
    params = parse_params(intcode, Enum.take(parameter_modes, param_count - 1))
    new_intcode = apply(operation, [intcode | params])
    case new_intcode.instruction_pointer do
      :halt ->
        new_intcode
      {:jump, location} ->
        %__MODULE__{new_intcode | instruction_pointer: location}
        |> execute
      i when is_integer(i) ->
        new_intcode
        |> advance(param_count)
        |> execute
    end
  end

  defp parse_opcode(intcode) do
    value = Map.fetch!(intcode.program, intcode.instruction_pointer)
    <<raw_parameter_modes::binary-size(3), opcode::binary-size(2)>> =
      '~5..0B'
      |> :io_lib.format([value])
      |> to_string
    {
      raw_parameter_modes
      |> String.graphemes
      |> Enum.reverse,
      String.to_integer(opcode)
    }
  end

  defp parse_params(intcode, parameter_modes) do
    parameter_modes
    |> Enum.with_index(intcode.instruction_pointer + 1)
    |> Enum.map(fn {parameter_mode, i} ->
      {
        Map.fetch!(intcode.program, i),
        case parameter_mode do
          "0" -> :position
          "1" -> :immediate
        end
      }
    end)
  end

  defp to_position({address, :position}), do: address

  defp interpret(program, {address, :position}) do
    Map.fetch!(program, address)
  end
  defp interpret(_program, {value, :immediate}), do: value

  defp write_to_program(intcode, address, new_value) do
    %__MODULE__{intcode | program: Map.put(intcode.program, address, new_value)}
  end

  defp advance(intcode, steps) do
    %__MODULE__{
      intcode |
      instruction_pointer: intcode.instruction_pointer + steps
    }
  end

  defp jump_to(intcode, location) do
    %__MODULE__{intcode | instruction_pointer: {:jump, location}}
  end

  defp compare(intcode, result_address, true) do
    write_to_program(intcode, result_address, 1)
  end
  defp compare(intcode, result_address, false) do
    write_to_program(intcode, result_address, 0)
  end
end

defmodule TEST do
  def run([path | input]) do
    path
    |> Intcode.new(Enum.map(input, fn i -> {n, ""} = Integer.parse(i); n end))
    |> Intcode.execute
    |> show_output
  end

  def show_output(intcode) do
    IO.puts intcode.output
  end
end

System.argv
|> TEST.run
