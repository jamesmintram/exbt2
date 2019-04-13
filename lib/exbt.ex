defmodule Exbt do
  @moduledoc """
  TODO: Support -ve numbers
  TODO: Work out stream support?
  """

  #----------------------------------------------
  # Parsing utils

  def parse_string_chars("", _, acc) do
    {acc, <<>>}
  end
  def parse_string_chars(rest, 0, acc) do
    {acc, rest}
  end
  def parse_string_chars(<<char::size(8)>> <> rest, len, acc) do
    parse_string_chars(rest, len - 1, [char | acc])
  end

  def parse_string(data) do
    {len, rest} = Integer.parse(data)
    ":" <> rest = rest

    {str, rest} = parse_string_chars(rest, len, [])
    str = Enum.reverse(str)

    {str, rest}
  end

  #----------------------------------------------
  # Parse terms

  def parse_term(<<c>> <> _rest = data, acc) when c in '1234567890' do
    {str, rest} = parse_string(data)
    {[[:string, str] | acc], rest}
  end

  def parse_term("i" <> rest, acc) do
    {int, rest} = Integer.parse(rest)
    "e" <> rest = rest
    {[[:int, int] | acc], rest}
  end

  def parse_term("l" <> rest, acc) do
    {[:list_start | acc], rest}
  end

  def parse_term("d" <> rest, acc) do
    {[:dictionary_start | acc], rest}
  end

  def parse_term("e" <> rest, acc) do
    {[:end | acc], rest}
  end

  def parse_term("", _acc) do
    raise "UNEXPECTED EOF"
  end

  def parse_term(data) do
    <<a>> <> <<b>> <> <<c>> <> _rest = data
    raise "UNEXPECTED END OF TERM " <> to_string([a, b, c])
  end

  def parse_terms(<<>>, acc) do
    acc
  end

  def parse_terms(rest, acc) do
    {acc, rest} = parse_term(rest, acc)
    parse_terms(rest, acc)
  end

  def create_terms(data) do
    data
    |> parse_terms([])
    |> Enum.reverse()
  end

  #----------------------------------------------
  # Inflate terms
  #----------------------------------------------

  def inflate_list([:end | rest], acc) do
    {acc, rest}
  end

  def inflate_list(rest, acc) do
    {val, rest} = inflate_terms(rest)
    inflate_list(rest, [val | acc])
  end

  def inflate_dictionary([:end | rest], acc) do
    {acc, rest}
  end

  def inflate_dictionary([[:string, key] | rest], acc) do
    {val, rest} = inflate_terms(rest)
    inflate_dictionary(rest, [{key, val} | acc])
  end

  #-------------------

  def inflate_terms([[:int, int] | rest]) do
    {int, rest}
  end

  def inflate_terms([[:string, str] | rest]) do
    {str, rest}
  end

  def inflate_terms([:list_start | rest]) do
    inflate_list(rest, [])
  end

  def inflate_terms([:dictionary_start | rest]) do
    {pairs, rest} = inflate_dictionary(rest, [])

    map = Map.new(pairs)

    {map, rest}
  end

  def inflate_terms([key | _rest]) do
    raise "Unhandled key: #{inspect key}"
  end

  def create_data(terms) do
    {data, _} = inflate_terms(terms)
    data
  end

  #----------------------------------------------

  def find_dictionary_end(_rest, acc, 0) do
    {:found, Enum.reverse(acc)}
  end

  def find_dictionary_end([], _acc, _ctr) do
    {:error, "Unbalanced start/end"}
  end

  def find_dictionary_end([:end | rest], acc, ctr) do
    find_dictionary_end(rest, [:end | acc], ctr - 1)
  end

  def find_dictionary_end([:dictionary_start | rest], acc, ctr) do
    find_dictionary_end(rest, [:dictionary_start | acc], ctr + 1)
  end

  def find_dictionary_end([:list_start | rest], acc, ctr) do
    find_dictionary_end(rest, [:list_start | acc], ctr + 1)
  end

  def find_dictionary_end([head | rest], acc, ctr) do
    find_dictionary_end(rest, [head | acc], ctr)
  end

  def extract_dictionary([]) do
    {:not_found, []}
  end

  def extract_dictionary([[:string, 'info'], :dictionary_start | rest]) do
    find_dictionary_end(rest, [:dictionary_start], 1)
  end

  def extract_dictionary([_head | rest]) do
    extract_dictionary(rest)
  end

  #----------------------------------------------

  def encode_list([], acc) do
    acc
  end

  def encode_list([:end | rest], acc) do
    encode_list(rest, acc <> "e")
  end

  def encode_list([[:int, int] | rest], acc) do
    encode_list(rest, acc <> "i" <> Integer.to_string(int) <> "e")
  end

  def encode_list([[:string, str] | rest], acc) do
    # encode_list(rest, acc <> length(str) <> ":" <> str)

    encode_list(
      rest,
      acc
      <> Integer.to_string(length(str))
      <> ":"
      <> List.to_string(str) )
  end

  def encode_list([:dictionary_start | rest], acc) do
    encode_list(rest, "d" <> acc)
  end

  # Unkown item
  def encode_list([_head | rest], acc) do
    encode_list(rest, acc)
  end


  #----------------------------------------------
  # Main parser

  def parse_torrent(data) do

    terms = create_terms(data)
    struct = create_data(terms)

    # IO.puts(inspect(terms))

    {:found, dict} = extract_dictionary(terms)
    # IO.puts(inspect(dict))
    encoded = encode_list(dict, "")

    {:ok, file} = File.open("priv/out.txt", [:write])
    IO.binwrite(file, encoded)
    File.close(file)


    hash = :crypto.hash(:sha, encoded)
    hex = Base.encode16(hash)

    IO.puts("ENCODED")
    IO.puts(hex)
    IO.puts("ENCODED")
    # TODO: Pass it into a struct

    struct
  end

  def hello do
    iodata = File.read!("priv/ubuntu2.torrent")
    data = IO.iodata_to_binary(iodata)

    parse_torrent(data)
  end
end
