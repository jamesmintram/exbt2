defmodule Bthash do

  def make_hashes() do
    file = File.stream!(
      "priv/ubuntu_invalid.iso",
      [],
      524288)

    hashes = Enum.map(
      file,
      fn (block) ->
          :crypto.hash(:sha, block)
      end)
    # |> Enum.zip(Stream.iterate(0, &(&1 + 1)))

    torrent = Exbt.hello()

    torrent_hashes = torrent
    |> get_in(['info', 'pieces'])
    |> Enum.chunk_every(20)
    |> Enum.zip(hashes)
    |> Enum.map(fn {fhash, thash} ->
      #TODO: Move this into BTFile loader
      fhash = :erlang.list_to_bitstring(fhash)
      fhash == thash
    end)
    |> Enum.zip(Stream.iterate(0, &(&1 + 1)))
    #|> Enum.count(fn result -> result == false end)

    IO.puts(inspect(torrent))
  end
end
