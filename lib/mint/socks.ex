defmodule Mint.SOCKS do
  @moduledoc """
  SOCKS proxy wrapper for gen_tcp.
  """

  @default_timeout 30_000

  @doc """
  Connects to a target host through a SOCKS5 proxy.

  Options:
  - :proxy_host - proxy hostname or IP
  - :proxy_port - proxy port
  - :timeout - connection timeout
  """
  def connect(host, port, opts) do
    proxy_host = Keyword.fetch!(opts, :proxy_host)
    proxy_port = Keyword.fetch!(opts, :proxy_port)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    proxy_host = if is_binary(proxy_host), do: String.to_charlist(proxy_host), else: proxy_host

    # Connect to proxy
    with {:ok, socket} <-
           :gen_tcp.connect(proxy_host, proxy_port, [:binary, active: false], timeout),
          :ok <- Mint.SOCKS.Protocol.handshake(socket, timeout),
          :ok <- Mint.SOCKS.Protocol.connect(socket, host, port, timeout) do
      {:ok, socket}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end


end
