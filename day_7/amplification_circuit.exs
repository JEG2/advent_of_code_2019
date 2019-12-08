defmodule Intcode do
  defstruct program: nil, output: nil, instruction_pointer: 0

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
      to_position(result_address),
      interpret(intcode.program, left) + interpret(intcode.program, right)
    )
  end

  def opcode_2(intcode, left, right, result_address) do
    write_to_program(
      intcode,
      to_position(result_address),
      interpret(intcode.program, left) * interpret(intcode.program, right)
    )
  end

  def opcode_3(intcode, address) do
    receive do
      input when is_integer(input) ->
        write_to_program(intcode, to_position(address), input)
    end
  end

  def opcode_4(intcode, value) do
    output = interpret(intcode.program, value)
    send(intcode.output, output)
    intcode
  end

  def opcode_5(intcode, condition, location) do
    if interpret(intcode.program, condition) != 0 do
      jump_to(intcode, interpret(intcode.program, location))
    else
      intcode
    end
  end

  def opcode_6(intcode, condition, location) do
    if interpret(intcode.program, condition) == 0 do
      jump_to(intcode, interpret(intcode.program, location))
    else
      intcode
    end
  end

  def opcode_7(intcode, left, right, result_address) do
    compare(
      intcode,
      to_position(result_address),
      interpret(intcode.program, left) < interpret(intcode.program, right)
    )
  end

  def opcode_8(intcode, left, right, result_address) do
    compare(
      intcode,
      to_position(result_address),
      interpret(intcode.program, left) == interpret(intcode.program, right)
    )
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

defmodule AmplificationCircuit do
  def run([path]) do
    intcode = Intcode.new(path)
    0..4
    |> Enum.to_list
    |> permutations
    |> Enum.map(fn phase_settings ->
      launch_amplifiers(intcode, phase_settings)
      receive do
        signal when is_integer(signal) ->
          signal
      end
    end)
    |> Enum.max
    |> IO.puts
  end
  def run(["-2", path]) do
    intcode = Intcode.new(path)
    5..9
    |> Enum.to_list
    |> permutations
    |> Enum.map(fn phase_settings ->
      loop = launch_amplifiers(intcode, phase_settings, :monitor)
      wait_for_halt(loop, nil, 0)
    end)
    |> Enum.max
    |> IO.puts
  end

  defp permutations([ ]), do: [[ ]]
  defp permutations(list) do
    for head <- list, tail <- permutations(list -- [head]), do: [head | tail]
  end

  defp launch_amplifiers(intcode, phase_settings, options \\ [ ]) do
    amplifier_a_pid =
      phase_settings
      |> Enum.reverse
      |> Enum.reduce(self(), fn phase_setting, output ->
        pid = Intcode.start(intcode, output)
        if :monitor in List.wrap(options) do
          Process.monitor(pid)
        end
        send(pid, phase_setting)
        pid
      end)
    send(amplifier_a_pid, 0)
    amplifier_a_pid
  end

  defp wait_for_halt(_loop, last_signal, 5), do: last_signal
  defp wait_for_halt(loop, last_signal, halted_count) do
    receive do
      signal when is_integer(signal) ->
        send(loop, signal)
        wait_for_halt(loop, signal, halted_count)
      {:DOWN, _ref, :process, _pid, _reason} ->
        wait_for_halt(loop, last_signal, halted_count + 1)
    end
  end
end

System.argv
|> AmplificationCircuit.run
