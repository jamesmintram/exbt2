defmodule Exbt.Torrent do
  alias Exbt.Bencode

  def from_binary(binary_data) do

    %{data: data, terms: terms} = Bencode.decode(binary_data)
    {:found, dict} = Bencode.extract_dictionary(terms)

    raw_hash = :crypto.hash_init(:sha)
    |> Bencode.encode_list(dict)
    |> :crypto.hash_final()

    Map.put(data, :info_hash, %{
      raw: raw_hash,
      uri: URI.encode(raw_hash)
    })
  end

  def from_file(file_path) do
    iodata = File.read!(file_path)
    binary_data = IO.iodata_to_binary(iodata)

    from_binary(binary_data)
  end

  def fetch_peers(torrent, self) do

    # TODO: Need a better way to describe this - part of app boot/config?
    {:ok, vsn} = :application.get_key(:exbt, :vsn)
    vsn = List.to_string(vsn)



    # Need some module for building these
    query = %{
      # Network
      peer_id: self.id,
      port: 51413,

      # Torrent specific
      info_hash: torrent.info_hash.raw,
      uploaded: 0,
      downloaded: 0,
      left: 1157627904,

      # Common
      compact: 1
    }

    response = HTTPotion.get(
      torrent['announce'],
      query: query)

    body_data = Bencode.decode(response.body)

    IO.puts(inspect(query))

    get_peers(body_data)
  end

  defp get_peers(%{data: response} = _data) do

    response
    |> Map.get('peers')
    |> Enum.chunk_every(6)
    |> Enum.map(&(:binary.list_to_bin(&1)))
    |> Enum.map(
      fn  <<ip1, ip2, ip3, ip4, port::size(16)>> ->
        {{ip1, ip2, ip3, ip4}, port}
      end)

    # Filter self?

  end


end
