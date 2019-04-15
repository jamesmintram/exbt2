defmodule Btpeer do
  use GenServer

  @choke 0
  @unchoke 1
  @interested 2
  @not_interested 3
  @have 4
  @bitfield 5
  @request 6
  @piece 7
  @cancel 8

  @extended 20

  @initial_state %{socket: nil}

  def start_link(config) do
    GenServer.start_link(
      __MODULE__,
      Map.put(@initial_state, :config, config))
  end

  def handle_data(<<>> ) do
    IO.puts("Keepalive")
  end
  def handle_data(<<_size::size(32), @choke::size(8), _payload::binary>>) do
    IO.puts("Choke")
  end
  def handle_data(<<_size::size(32), @unchoke::size(8), _payload::binary>>) do
    IO.puts("Unchoke")
  end
  def handle_data(<<_size::size(32), @interested::size(8), _payload::binary>>) do
    IO.puts("Interested")
  end
  def handle_data(<<_size::size(32), @not_interested::size(8), _payload::binary>>) do
    IO.puts("NotInterested")
  end
  def handle_data(<<_size::size(32), @have::size(8), _payload::binary>>) do
    IO.puts("Have")
  end
  def handle_data(<<_size::size(32), @bitfield::size(8), _payload::binary>>) do
    IO.puts("Bitfield")
  end
  def handle_data(<<_size::size(32), @request::size(8), _payload::binary>>) do
    IO.puts("Request")
  end
  def handle_data(<<_size::size(32), @piece::size(8), _payload::binary>>) do
    IO.puts("Piece")
  end
  def handle_data(<<_size::size(32), @cancel::size(8), _payload::binary>>) do
    IO.puts("Cancel")
  end
  def handle_data(<<_size::size(32), @extended::size(8), _payload::binary>>) do
    IO.puts("Unhandled extended payload")
  end
  def handle_data(
    <<_size::size(32),
      unkown_type::size(8),
      _payload::binary>> = _data) do

    IO.puts("Unkown type #{unkown_type}, skipping")
  end

  # def handle_socket(socket) do
  #   {:ok, rest} = :gen_tcp.recv(socket, 0)
  #   handle_data(rest)

  #   handle_socket(socket)
  # end



  def handle_info({:tcp, _, data}, %{state: :new} = state) do
    # Logger.info "Received #{data}"
    IO.puts("Handshake")

    <<0x13,
      protocol::binary - size(19),
      _reserved::binary - size(8),
      info_hash::binary - size(20),
      _peer_id::binary - size(20),
      _rest::binary
      >> = data

    IO.puts("Response:")
    IO.puts("Protocol: #{to_string(protocol)}")
    IO.puts("InfoHash: #{Base.encode16(info_hash)}")

    state = Map.put(state, :state, :connected)

    {:noreply, state}
  end

  def handle_info({:tcp, _, data}, state) do
    handle_data(data)
    {:noreply, state}
  end

  def init(state) do
    opts = [:binary, active: true]
    config = state.config

    IO.puts("Connecting to peer: #{inspect(config.host)}")

    {:ok, socket} = :gen_tcp.connect(config.host, config.port, opts)

    # TODO: Encode handshake
    handshake = <<0x13>>
    <> "BitTorrent protocol"
    <> <<0x0, 0x0, 0x0, 0x0, 0x0, 0x10, 0x0, 0x4>>
    <> config.torrent.info_hash.raw
    <> config.self.id

    IO.puts(Base.encode16(handshake))

    :ok = :gen_tcp.send(socket, handshake)

    # {:ok, msg} = :gen_tcp.recv(socket, 0)



    # Task.start_link(fn -> handle_socket(socket) end)

    state = state
    |> Map.put(:socket, socket)
    |> Map.put(:state, :new)

    {:ok, state}
  end
end




    # Pretty gross, any better way?
    # msg_hex = msg
    # |> Base.encode16()
    # |> String.to_charlist()
    # |> Enum.chunk_every(2)
    # |> Enum.join(" ")
    # |> String.to_charlist()
    # |> Enum.chunk_every(16 * 3)
    # |> Enum.join("\n")

    # Parse msg back into a header struct
    # IO.puts("Response: \n #{msg_hex}")
