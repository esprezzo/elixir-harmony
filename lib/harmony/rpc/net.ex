defmodule Harmony.Net do
  @moduledoc """
  Net Namespace for Harmony JSON-RPC
  """
  require Harmony.Transport

  @doc """
  Show version of network
      
  ## Example:

      iex> Harmony.version()
      {:ok, "1"}
 
  """
  @spec version :: {:ok, float} | {:error, String.t}
  def version do
    case __MODULE__.send("net_version",[]) do
      {:ok, version} ->
        {:ok, version}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Show network version identifier

  ## Example:
      
      iex> Harmony.peer_count
      {:ok, "19"}

  """
  @spec peer_count :: {:ok, integer} | {:error, String.t}
  def peer_count do
    case __MODULE__.send("net_peerCount",[]) do
      {:ok, count} ->
        count
        |> Hexate.to_integer
        {:ok, count}
      {:error, reason} ->
        {:error, reason}
    end
  end


  @doc """
  Display node listening status
  
  ## Example:
      
      iex> Harmony.listening
      {:ok, true}

  """
  @spec listening :: {:ok, boolean} | {:error, String.t}
  def listening do
    case __MODULE__.send("net_listening",[]) do
      {:ok, response} ->
        {:ok, response}
      {:error, reason} ->
        {:error, reason}
    end
  end

end
