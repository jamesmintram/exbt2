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

  @initial_state %{socket: nil, piece_idx: 0, chunk_data: <<>>}

  @handshake_opts  [:binary, active: true]
  @connection_opts  [:binary, active: true, packet: 4]

  @chunk_size 1024 * 512
  @piece_size 0x4000

  def start_link(config) do
    GenServer.start_link(
      __MODULE__,
      Map.put(@initial_state, :config, config))
  end

  def handle_data(<<>>, state) do
    IO.puts("Keepalive")
    state
  end
  def handle_data(<<@choke::size(8)>> = data, state) do
    IO.puts("Choke")
    IO.puts(inspect(data))
    state
  end
  def handle_data(<<@unchoke::size(8)>>, state) do
    IO.puts("Unchoke")
    Map.put(state, :state, :unchoked)
  end
  def handle_data(<<@interested::size(8), _payload::binary>>, state) do
    IO.puts("Interested")
    state
  end
  def handle_data(<<@not_interested::size(8), _payload::binary>>, state) do
    IO.puts("NotInterested")
    state
  end
  def handle_data(<<@have::size(8), _payload::binary>>, state) do
    IO.puts("Have")
    state
  end
  def handle_data(<<@bitfield::size(8), _payload::binary>>, state) do
    IO.puts("Bitfield")
    state
  end
  def handle_data(<<@request::size(8), _payload::binary>>, state) do
    IO.puts("Request")
    state
  end
  def handle_data(<<@piece::size(8), payload::binary>>, state) do
    IO.puts("Piece at offset #{state.piece_idx}")

    payload_size = byte_size(payload)
    next_idx = state.piece_idx + payload_size

    # Update the downloaded data
    state = state
      |> Map.update(:chunk_data, <<>>, &(&1 <> payload))
      |> Map.update(:piece_idx, 0, &(&1 + payload_size))

    if next_idx > @chunk_size do
      IO.puts("Chunk complete at: #{next_idx}")
      IO.puts("Chunk Size: #{byte_size(state.chunk_data)}")

      # Do something with the completed chunk
      hex_sha = Base.encode16(:crypto.hash(:sha, state.chunk_data))


      t_hex_sha = state.config.torrent
      |> get_in(['info', 'pieces'])
      |> Enum.take(20)
      |> :erlang.list_to_bitstring()
      |> Base.encode16()

      IO.puts(hex_sha)
      IO.puts(t_hex_sha)

      File.write("priv/chunk0.bin", state.chunk_data)

      state
      |> Map.put(:state, :complete)
      |> Map.put(:piece_idx, 0)
      |> Map.put(:chunk_data, <<>>)
    else
      IO.puts("Next piece: #{next_idx}")
      state
      |> Map.put(:state, :unchoked)

    end
  end

  def handle_data(<<@cancel::size(8), _payload::binary>>, state) do
    IO.puts("Cancel")
    state
  end
  def handle_data(<<@extended::size(8), _payload::binary>>, state) do
    IO.puts("Unhandled extended payload")
    state
  end
  def handle_data(
    << unkown_type::size(8),
      _payload::binary>> = _data, state) do

    IO.puts("Unkown type #{unkown_type}, skipping")
    state
  end

  def handle_info({:tcp, socket, data}, %{state: :new} = state) do
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

    :inet.setopts(socket, @connection_opts)

    {:noreply, state}
  end

  def handle_info({:tcp, socket, data}, state) do
    # Reciever state to say we are recieving something? Buffer it in memory?
    # Once we have reached the piece size we are expecting, return to :recv_state

    IO.puts("Handle info")
    IO.puts(inspect(data))
    new_state = handle_data(data, state)
    new_state = update(new_state.state, new_state, socket)

    # Return a timeout for 10s?

    {:noreply, new_state}
  end

  def handle_info({:tcp_closed, _}, state) do
    IO.puts("tcp close")
    {:stop, :normal, state}
  end
  def handle_info({:tcp_error, _, err}, state) do
    IO.puts("tcp error")
    IO.puts(inspect(err, pretty: true))
    {:stop, :normal, state}
  end

  def update(:unchoked, state, socket) do

    data_remaining = @chunk_size - state.piece_idx
    chunk_size = min(@piece_size, data_remaining)

    data_request = <<
      # <<13::big-size(32)>>,
      @request,
      0::big-size(32),                  # Piece index
      state.piece_idx::big-size(32),    # Piece offset
      chunk_size::big-size(32)          # Piece size
    >>
    IO.puts("Requesting data: #{chunk_size}")
    :gen_tcp.send(socket, data_request)

    Map.put(state, :state, :awaiting_data)
  end

  def update(_status, state, _) do
    state
  end

  def init(state) do

    config = state.config

    IO.puts("Connecting to peer: #{inspect(config.host)}")

    {:ok, socket} = :gen_tcp.connect(config.host, config.port, @handshake_opts)

    # TODO: Encode handshake
    handshake = <<0x13>>
    <> "BitTorrent protocol"
    <> <<0x0, 0x0, 0x0, 0x0, 0x0, 0x10, 0x0, 0x4>>
    <> config.torrent.info_hash.raw
    <> config.self.id

    :ok = :gen_tcp.send(socket, handshake)



    # {:ok, msg} = :gen_tcp.recv(socket, 0)

    IO.puts("Sent handshake")

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
