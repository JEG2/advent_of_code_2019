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

defmodule SpacePolice do
  defstruct pid: nil, xy: {0, 0}, direction: :north, painted: Map.new

  def run([path]) do
    intcode = Intcode.new(path)
    pid = Intcode.start(intcode, self())
    Process.monitor(pid)

    %__MODULE__{pid: pid}
    |> run_robot
    |> count_painted
  end
  def run(["-2", path]) do
    intcode = Intcode.new(path)
    pid = Intcode.start(intcode, self())
    Process.monitor(pid)

    %__MODULE__{pid: pid, painted: %{{0, 0} => 1}}
    |> run_robot
    |> show_painting
  end

  defp run_robot(robot) do
    send(robot.pid, Map.get(robot.painted, robot.xy, 0))

    receive do
      {:DOWN, _reference, :process, _pid, _reason} ->
        robot
      color ->
        new_painted = Map.put(robot.painted, robot.xy, color)

        new_direction =
          receive do
            0 ->
              turn(robot.direction, :left)
            1 ->
              turn(robot.direction, :right)
          end

        new_xy = advance(robot.xy, new_direction)

        %__MODULE__{
          robot |
          xy: new_xy, direction: new_direction, painted: new_painted
        }
        |> run_robot
    end
  end

  defp turn(:north, :left), do: :west
  defp turn(:north, :right), do: :east
  defp turn(:east, :left), do: :north
  defp turn(:east, :right), do: :south
  defp turn(:south, :left), do: :east
  defp turn(:south, :right), do: :west
  defp turn(:west, :left), do: :south
  defp turn(:west, :right), do: :north

  defp advance({x, y}, :north), do: {x, y - 1}
  defp advance({x, y}, :east), do: {x + 1, y}
  defp advance({x, y}, :south), do: {x, y + 1}
  defp advance({x, y}, :west), do: {x - 1, y}

  defp count_painted(robot) do
    robot.painted
    |> map_size
    |> IO.puts
  end

  defp show_painting(robot) do
    min_x =
      robot.painted
      |> Map.keys
      |> Enum.map(fn {x, _y} -> x end)
      |> Enum.min
    robot.painted
    |> Enum.sort_by(fn {{x, y}, _color} -> [y, x] end)
    |> Enum.chunk_by(fn {{_x, y}, _color} -> y end)
    |> Enum.each(fn line ->
      IO.write String.duplicate(" ", line |> hd |> elem(0) |> elem(0) |> Kernel.-(min_x))
      line
      |> Enum.map(fn {_xy, 0} -> " "; {_xy, 1} -> "#" end)
      |> IO.puts
    end)
  end
end

System.argv
|> SpacePolice.run
