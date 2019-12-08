defmodule SpaceImageFormat do
  def run([path, width, height]) do
    path
    |> read_layers(String.to_integer(width), String.to_integer(height))
    |> check_layers
    |> show_checksum
  end
  def run(["-2", path, width, height]) do
    {width, height} = {String.to_integer(width), String.to_integer(height)}
    path
    |> read_layers(width, height)
    |> combine_layers
    |> render_image(width)
  end

  defp read_layers(path, width, height) do
    path
    |> File.stream!([ ], width * height)
    |> Stream.filter(fn layer -> String.match?(layer, ~r{\A\d+\z}) end)
    |> Stream.map(fn layer -> String.graphemes(layer) end)
  end

  defp check_layers(layers) do
    fewest_zeros =
      Enum.min_by(layers, fn layer -> count_in_layer(layer, "0") end)
    count_in_layer(fewest_zeros, "1") * count_in_layer(fewest_zeros, "2")
  end

  defp count_in_layer(layer, digit) do
    layer
    |> Enum.filter(fn d -> d == digit end)
    |> length
  end

  defp show_checksum(count) do
    IO.puts count
  end

  defp combine_layers(layers) do
    Enum.reduce(layers, fn layer, image ->
      image
      |> Enum.zip(layer)
      |> Enum.map(fn {"2", back} -> back; {front, _back} -> front end)
    end)
  end

  defp render_image(image, width) do
    image
    |> Enum.map(fn "1" -> "*"; _digit -> " " end)
    |> Enum.chunk_every(width)
    |> Enum.each(fn row -> IO.puts row end)
  end
end

System.argv
|> SpaceImageFormat.run
