defmodule Exbt.Peer do

  def create() do
    %{
      # id: "Exbt #{vsn}" #TODO: How can we send this to tracker?
      id: random_peer_id(),
    }
  end

  def to_str({{ip1, ip2, ip3, ip4}, peer_port}) do
    "#{ip1}.#{ip2}.#{ip3}.#{ip4}:#{peer_port}"
  end

  defp random_peer_id() do
    :crypto.strong_rand_bytes(20) |> Base.url_encode64 |> binary_part(0, 20)
  end
end
