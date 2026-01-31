defmodule TrinityVsa do
  @moduledoc """
  Trinity VSA - Vector Symbolic Architecture with balanced ternary arithmetic
  """

  @doc "Create zero vector"
  def zeros(dim), do: List.duplicate(0, dim)

  @doc "Create random vector"
  def random(dim, seed \\ nil) do
    if seed, do: :rand.seed(:exsss, {seed, seed, seed})
    Enum.map(1..dim, fn _ -> :rand.uniform(3) - 2 end)
  end

  @doc "Bind two vectors (element-wise multiplication)"
  def bind(a, b) when length(a) == length(b) do
    Enum.zip_with(a, b, &(&1 * &2))
  end

  @doc "Unbind (inverse of bind)"
  def unbind(a, b), do: bind(a, b)

  @doc "Bundle vectors via majority voting"
  def bundle([]), do: raise("Empty vector list")
  def bundle(vectors) do
    dim = length(hd(vectors))
    Enum.map(0..(dim - 1), fn i ->
      sum = Enum.sum(Enum.map(vectors, &Enum.at(&1, i)))
      cond do
        sum > 0 -> 1
        sum < 0 -> -1
        true -> 0
      end
    end)
  end

  @doc "Circular permutation"
  def permute(v, shift) do
    dim = length(v)
    {left, right} = Enum.split(v, rem(dim - shift, dim))
    right ++ left
  end

  @doc "Dot product"
  def dot(a, b) when length(a) == length(b) do
    Enum.zip_with(a, b, &(&1 * &2)) |> Enum.sum()
  end

  @doc "Cosine similarity"
  def similarity(a, b) do
    d = dot(a, b)
    norm_a = :math.sqrt(dot(a, a))
    norm_b = :math.sqrt(dot(b, b))
    if norm_a == 0 or norm_b == 0, do: 0.0, else: d / (norm_a * norm_b)
  end

  @doc "Hamming distance"
  def hamming_distance(a, b) when length(a) == length(b) do
    Enum.zip_with(a, b, fn x, y -> if x != y, do: 1, else: 0 end) |> Enum.sum()
  end
end
