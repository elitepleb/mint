defmodule Mint.Core.Transport.SOCKS do
  @moduledoc false

  @behaviour Mint.Core.Transport

  @transport_opts [
    packet: :raw,
    mode: :binary,
    active: false
  ]

  @default_timeout 30_000

  @impl true
  def connect(address, port, opts) do
    {proxy_host, opts} = Keyword.pop!(opts, :proxy_host)
    {proxy_port, opts} = Keyword.pop!(opts, :proxy_port)

    timeout = Keyword.get(opts, :timeout, @default_timeout)

    opts = Keyword.merge(opts, @transport_opts)

    opts =
      Keyword.drop(opts, [
        :alpn_advertised_protocols,
        :timeout,
        :transport,
        :hostname,
        :cacertfile
      ])

    proxy_host = if is_binary(proxy_host), do: String.to_charlist(proxy_host), else: proxy_host

    # First connect to proxy normally, then do SOCKS handshake
    with {:ok, socket} <- :gen_tcp.connect(proxy_host, proxy_port, opts, timeout),
          :ok <- Mint.SOCKS.Protocol.handshake(socket, timeout),
          :ok <- Mint.SOCKS.Protocol.connect(socket, address, port, timeout) do
      {:ok, socket}
    else
      {:error, reason} ->
        {:error, wrap_error(reason)}
    end
  end

  @impl true
  def upgrade(socket, scheme, hostname, _port, opts) do
    case scheme do
      :https ->
        # Upgrade to SSL
        ssl_opts =
          Keyword.take(opts, [
            :cacertfile,
            :certfile,
            :keyfile,
            :password,
            :verify,
            :verify_fun,
            :fail_if_no_peer_cert,
            :depth,
            :server_name_indication
          ])
          |> Keyword.put_new(:server_name_indication, hostname)

        :ssl.connect(socket, ssl_opts)

      _ ->
        {:ok, socket}
    end
  end

  @impl true
  def negotiated_protocol(_socket), do: wrap_error({:error, :protocol_not_negotiated})

  @impl true
  def send(socket, payload) do
    wrap_err(:gen_tcp.send(socket, payload))
  end

  @impl true
  defdelegate close(socket), to: :gen_tcp

  @impl true
  def recv(socket, bytes, timeout) do
    wrap_err(:gen_tcp.recv(socket, bytes, timeout))
  end

  @impl true
  def controlling_process(socket, pid) do
    wrap_err(:gen_tcp.controlling_process(socket, pid))
  end

  @impl true
  def setopts(socket, opts) do
    wrap_err(:inet.setopts(socket, opts))
  end

  @impl true
  def getopts(socket, opts) do
    wrap_err(:inet.getopts(socket, opts))
  end

  @impl true
  def wrap_error(reason) do
    %Mint.TransportError{reason: reason}
  end

  defp wrap_err({:error, reason}), do: {:error, wrap_error(reason)}
  defp wrap_err(other), do: other


end
