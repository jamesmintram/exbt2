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
  # Main parser

  def parse_torrent(data) do

    struct = data
    |> create_terms()
    |> create_data()

    # TODO: Pass it into a struct

    struct
  end

  def hello do
    iodata = File.read!("priv/ubuntu2.torrent")
    data = IO.iodata_to_binary(iodata)

    parse_torrent(data)
  end
end
