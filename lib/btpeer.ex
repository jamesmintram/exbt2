defmodule Btpeer do
  use GenServer

  @initial_state %{socket: nil}

  def start_link(config) do
    GenServer.start_link(
      __MODULE__,
      Map.put(@initial_state, :config, config))
  end

  def init(state) do
    opts = [:binary, active: false]
    config = state.config

    {:ok, socket} = :gen_tcp.connect(config.host, config.port, opts)

    # TODO: Encode handshake
    handshake = <<0x13>>
    <> "BitTorrent protocol"
    <> <<0x0, 0x0, 0x0, 0x0, 0x0, 0x10, 0x0, 0x4>>
    <> config.torrent.info_hash.raw
    <> config.self.id

    IO.puts(Base.encode16(handshake))

    :ok = :gen_tcp.send(socket, handshake)

    {:ok, msg} = :gen_tcp.recv(socket, 0)


    # Pretty gross, any better way?
    msg_hex = msg
    |> Base.encode16()
    |> String.to_charlist()
    |> Enum.chunk_every(2)
    |> Enum.join(" ")
    |> String.to_charlist()
    |> Enum.chunk_every(16 * 3)
    |> Enum.join("\n")

    # Parse msg back into a header struct
    IO.puts("Response: \n #{msg_hex}")

    {:ok, %{state | socket: socket}}
  end
end
