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

  def encode_list(hasher, []) do
    hasher
  end

  def encode_list(hasher, [:end | rest]) do
    hasher = :crypto.hash_update(hasher, "e")
    encode_list(hasher, rest)
  end

  def encode_list(hasher, [[:int, int] | rest]) do
    hasher = :crypto.hash_update(hasher, "i")
    hasher = :crypto.hash_update(hasher, Integer.to_string(int))
    hasher = :crypto.hash_update(hasher, "e")

    encode_list(hasher, rest)
  end

  def encode_list(hasher, [[:string, str] | rest]) do
    hasher = :crypto.hash_update(hasher, Integer.to_string(length(str)))
    hasher = :crypto.hash_update(hasher, ":")
    hasher = :crypto.hash_update(hasher, str)

    encode_list(hasher, rest)
  end

  def encode_list(hasher, [:dictionary_start | rest]) do
    hasher = :crypto.hash_update(hasher, "d")
    encode_list(hasher, rest)
  end

  # Unkown item
  def encode_list(hasher, [_head | rest]) do
    encode_list(hasher, rest)
  end


  #----------------------------------------------
  # Main parser

  def parse_bencode(data) do

    terms = create_terms(data)
    struct = create_data(terms)


    # {:found, dict} = extract_dictionary(terms)

    # hash = :crypto.hash_init(:sha)
    # |> encode_list(dict)
    # |> :crypto.hash_final()
    # |> URI.encode()

    # IO.puts("info_hash #{hash}")


    struct
  end

  # Parse torrent struct
  # Parse response struct
  def get_peers(response) do

    response
    |> Map.get('peers')
    |> Enum.chunk_every(6)
    |> Enum.map(&(:binary.list_to_bin(&1)))
    |> Enum.map(
      fn  <<ip1, ip2, ip3, ip4, port::size(16)>> ->
        {{ip1, ip2, ip3, ip4}, port}
      end)

  end

  def hello do
    # iodata = File.read!("priv/ubuntu2.torrent")
    iodata = File.read!("priv/peers.txt")
    data = IO.iodata_to_binary(iodata)

    peers = data
    |> parse_bencode()
    |> get_peers()

    IO.puts(inspect(peers, pretty: true))
  end
end
