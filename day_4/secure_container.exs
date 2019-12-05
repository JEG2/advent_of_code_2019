defmodule SecureContainer do
  def run([ ], range) do
    process(range)
  end
  def run(["-2"], range) do
    process(range, &filter_larger_matching_groups/1)
  end

  defp process(range, filter \\ fn stream -> stream end) do
    range.first
    |> find_first_valid(filter)
    |> to_string
    |> Stream.unfold(fn
      nil ->
        nil
      password ->
      if String.to_integer(password) > range.last do
        nil
      else
        next_password =
          Regex.replace(
            ~r"(?:(?=\d{0,3}(\d)\1)\d{5}[0-8]|[0-8]9+|[0-8]9*\d?)\z",
            password,
            fn
              <<d::utf8, _rest::binary>> = match, "" ->
                d - ?0 + 1
                |> to_string
                |> String.duplicate(String.length(match))
              <<prefix::binary-size(5), d::utf8>>, _dup ->
                prefix <> to_string(d - ?0 + 1)
            end
          )
        {password, next_password}
      end
    end)
    |> filter.()
    |> Enum.count
    |> IO.puts
  end

  defp find_first_valid(start, filter) do
    start
    |> Stream.iterate(fn n -> n + 1 end)
    |> Stream.map(&to_string/1)
    |> filter.()
    |> Enum.find(&valid?/1)
  end

  def valid?(password) do
    String.length(password) == 6 &&
      String.match?(password, ~r"(\d)\1") &&
      String.match?(
        password,
        ~r"
          \A (?: 0(?=[0-9]) | 1(?=[1-9]) | 2(?=[2-9]) | 3(?=[3-9]) | 4(?=[4-9])
            | 5(?=[5-9]) | 6(?=[6-9]) | 7(?=[7-9]) | 8(?=[8-9]) | 9(?=9) ){5}
        "x
      )
  end

  defp filter_larger_matching_groups(stream) do
    Stream.filter(stream, fn password ->
      password
      |> String.replace(~r"(\d)\1{2,}", "X", global: true)
      |> String.match?(~r{(\d)\1})
    end)
  end
end

System.argv
|> SecureContainer.run(256310..732736)
