defmodule Mint.SOCKS.Protocol do
  @moduledoc false

  @socks5_version 0x05
  @socks5_connect 0x01
  @socks5_no_auth 0x00
  @socks5_atyp_domain 0x03
  @socks5_atyp_ipv4 0x01
  @socks5_atyp_ipv6 0x04

  def handshake(socket, timeout) do
    # Send version 5, 1 method: no auth
    packet = <<@socks5_version, 1, @socks5_no_auth>>

    with :ok <- :gen_tcp.send(socket, packet),
         {:ok, <<@socks5_version, @socks5_no_auth>>} <- :gen_tcp.recv(socket, 2, timeout) do
      :ok
    else
      _ -> {:error, :socks_handshake_failed}
    end
  end

  def connect(socket, address, port, timeout) do
    {atyp, addr} = encode_address(address)
    packet = <<@socks5_version, @socks5_connect, 0, atyp>> <> addr <> <<port::16>>

    with :ok <- :gen_tcp.send(socket, packet),
         {:ok, response} <- :gen_tcp.recv(socket, 0, timeout) do
      case response do
        <<@socks5_version, 0, 0, _::binary>> -> :ok
        <<@socks5_version, status, 0, _::binary>> -> {:error, {:socks_connect_failed, status}}
        _ -> {:error, :invalid_socks_response}
      end
    end
  end

  def encode_address(address) when is_binary(address) do
    case :inet.parse_address(String.to_charlist(address)) do
      {:ok, {a, b, c, d}} ->
        {@socks5_atyp_ipv4, <<a, b, c, d>>}

      {:ok, {a, b, c, d, e, f, g, h}} ->
        {@socks5_atyp_ipv6, <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>}

      _ ->
        # Domain name
        {@socks5_atyp_domain, <<byte_size(address)>> <> address}
    end
  end

  def encode_address(address) when is_list(address) do
    encode_address(to_string(address))
  end

  def encode_address({a, b, c, d}) do
    {@socks5_atyp_ipv4, <<a, b, c, d>>}
  end

  def encode_address({a, b, c, d, e, f, g, h}) do
    {@socks5_atyp_ipv6, <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>}
  end
end