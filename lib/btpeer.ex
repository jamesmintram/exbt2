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

  def handle_data(<<0, 0, 0, 0>>, state) do
    IO.puts("Keepalive")
    state
  end
  def handle_data(<<_size::size(32), @choke::size(8), _payload::binary>> = data, state) do
    IO.puts("Choke")
    IO.puts(inspect(data))
    state
  end
  def handle_data(<<_size::size(32), @unchoke::size(8), _payload::binary>>, state) do
    IO.puts("Unchoke")
    Map.put(state, :state, :unchoked)
  end
  def handle_data(<<_size::size(32), @interested::size(8), _payload::binary>>, state) do
    IO.puts("Interested")
    state
  end
  def handle_data(<<_size::size(32), @not_interested::size(8), _payload::binary>>, state) do
    IO.puts("NotInterested")
    state
  end
  def handle_data(<<_size::size(32), @have::size(8), _payload::binary>>, state) do
    IO.puts("Have")
    state
  end
  def handle_data(<<_size::size(32), @bitfield::size(8), _payload::binary>>, state) do
    IO.puts("Bitfield")
    state
  end
  def handle_data(<<_size::size(32), @request::size(8), _payload::binary>>, state) do
    IO.puts("Request")
    state
  end
  def handle_data(<<_size::size(32), @piece::size(8), _payload::binary>>, state) do
    IO.puts("Piece")
    state
  end
  def handle_data(<<_size::size(32), @cancel::size(8), _payload::binary>>, state) do
    IO.puts("Cancel")
    state
  end
  def handle_data(<<_size::size(32), @extended::size(8), _payload::binary>>, state) do
    IO.puts("Unhandled extended payload")
    state
  end
  def handle_data(
    <<_size::size(32),
      unkown_type::size(8),
      _payload::binary>> = _data, state) do

    IO.puts("Unkown type #{unkown_type}, skipping")
    state
  end

  def handle_info({:tcp, _, data}, %{state: :new} = state) do
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

  def handle_info({:tcp, socket, data}, state) do
    # Reciever state to say we are recieving something? Buffer it in memory?
    # Once we have reached the piece size we are expecting, return to :recv_state

    IO.puts("Handle info")
    new_state = handle_data(data, state)
    new_state = update(new_state.state, new_state, socket)

    # Return a timeout for 10s?

    {:noreply, new_state}
  end

  def handle_info({:tcp_closed, _}, state) do
    IO.puts("tcp close")
    {:stop, :normal, state}
  end
  def handle_info({:tcp_error, _}, state) do
    IO.puts("tcp error")
    {:stop, :normal, state}
  end

  def update(:unchoked, state, socket) do
    data_request = <<
      <<13::big-size(32)>>,
      @request,
      0::big-size(32),     # Piece index
      0::big-size(32),     # Piece offset
      0x4000::big-size(32) # Piece size
    >>
    IO.puts("Requesting data")
    :gen_tcp.send(socket, data_request)

    Map.put(state, :state, :awaiting_data)
  end

  def update(_status, state, _) do
    state
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
