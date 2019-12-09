defmodule Intcode do
  defstruct program: nil, output: nil, instruction_pointer: 0, relative_base: 0

  def new(path) do
    %__MODULE__{program: parse_program(path)}
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

  def start(intcode, output) do
    spawn(__MODULE__, :execute, [%__MODULE__{intcode | output: output}])
  end

  def execute(intcode) do
    {parameter_modes, opcode} = parse_opcode(intcode)
    function_name = :"opcode_#{opcode}"
    param_count =
      __MODULE__.__info__(:functions)
      |> Keyword.fetch!(function_name)
    params = parse_params(intcode, Enum.take(parameter_modes, param_count - 1))
    new_intcode = apply(__MODULE__, function_name, [intcode | params])
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

  def opcode_1(intcode, left, right, result_address) do
    write_to_program(
      intcode,
      result_address,
      interpret(intcode, left) + interpret(intcode, right)
    )
  end

  def opcode_2(intcode, left, right, result_address) do
    write_to_program(
      intcode,
      result_address,
      interpret(intcode, left) * interpret(intcode, right)
    )
  end

  def opcode_3(intcode, address) do
    receive do
      input when is_integer(input) ->
        write_to_program(intcode, address, input)
    end
  end

  def opcode_4(intcode, value) do
    output = interpret(intcode, value)
    send(intcode.output, output)
    intcode
  end

  def opcode_5(intcode, condition, location) do
    if interpret(intcode, condition) != 0 do
      jump_to(intcode, interpret(intcode, location))
    else
      intcode
    end
  end

  def opcode_6(intcode, condition, location) do
    if interpret(intcode, condition) == 0 do
      jump_to(intcode, interpret(intcode, location))
    else
      intcode
    end
  end

  def opcode_7(intcode, left, right, result_address) do
    compare(
      intcode,
      result_address,
      interpret(intcode, left) < interpret(intcode, right)
    )
  end

  def opcode_8(intcode, left, right, result_address) do
    compare(
      intcode,
      result_address,
      interpret(intcode, left) == interpret(intcode, right)
    )
  end

  def opcode_9(intcode, adjustment) do
    %__MODULE__{
      intcode |
      relative_base: intcode.relative_base + interpret(intcode, adjustment)
    }
  end

  def opcode_99(intcode) do
    %__MODULE__{intcode | instruction_pointer: :halt}
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
          "2" -> :relative
        end
      }
    end)
  end

  defp interpret(intcode, {address, :position}) do
    read(intcode, address)
  end
  defp interpret(intcode, {address, :relative}) do
    read(intcode, intcode.relative_base + address)
  end
  defp interpret(_intcode, {value, :immediate}), do: value

  defp write_to_program(intcode, param, new_value) do
    address =
      case param do
        {absolute, :position} ->
          absolute
        {relative, :relative} ->
          intcode.relative_base + relative
      end
    %__MODULE__{intcode | program: write(intcode, address, new_value)}
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

  defp read(intcode, address) when address >= 0 do
    Map.get(intcode.program, address, 0)
  end

  defp write(intcode, address, new_value) when address >= 0 do
    Map.put(intcode.program, address, new_value)
  end
end

defmodule BOOST do
  def run([path | input]) do
    pid =
      path
      |> Intcode.new
      |> Intcode.start(self())
    Enum.each(input, fn i ->
      {n, ""} = Integer.parse(i)
      send(pid, n)
    end)
    show_output()
  end

  def show_output do
    receive do
      output when is_integer(output) ->
        IO.puts output
    end
  end
end

System.argv
|> BOOST.run
