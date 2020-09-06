defmodule Exbt do
  @moduledoc """
  TODO: Support -ve numbers
  TODO: Work out stream support?
  """

  alias Exbt.Torrent
  alias Exbt.Peer
  alias Exbt.Downloader

  # Parse torrent struct
  # Parse response struct

  @self Peer.create()

  def hello do

    IO.puts(inspect(@self))

    torrent = Torrent.from_file("priv/testpg.torrent")
    {:ok, peers} = Torrent.fetch_peers(torrent, @self)

    IO.puts("Peers retrieved")
    Enum.map(peers, fn peer -> IO.puts("\t" <> Peer.to_str(peer)) end)

    [___, {peer_host, peer_port} | _] = peers

    {:ok, _pid} = Downloader.start_link(%{
      host: peer_host,
      port: peer_port,
      self: @self,
      torrent: torrent,
    })

    # IO.puts("Connect to #{ip1}.#{ip2}.#{ip3}.#{ip4}:#{peer_port}")
  end
end
