defmodule Harmony.TxPool do
  @moduledoc """
  Web3 Namespace Functions for Harmony JSON-RPC

  {:ok, %{"pending" => pending, }} = {:ok, x} = Harmony.TxPool.txpool_content()

  {:ok, %{"pending" => pending, "queued" => queued}} = Harmony.TxPool.txpool_content()
  {:ok, %{"pending" => pending, "queued" => _}} = Harmony.TxPool.txpool_inspect()
  {:ok, %{"pending" => _, "queued" => _}} = Harmony.TxPool.txpool_inspect()
  """
  alias Harmony.Transport
  require IEx
  require Logger
  @doc """
    
  Displays content of Harmony node.

  ## Example:

      iex> Harmony.TxPool.txpool_content()
      {:ok, "Geth/v1.6.5-stable-cf87713d/darwin-amd64/go1.8.3"}
      
  """
  @spec txpool_content :: {:ok, String.t} | {:error, String.t}
  def txpool_content do
    case Transport.send("txpool_content",[]) do
      {:ok, content} ->
        {:ok, content}
      {:error, reason} ->
        {:error, reason}
    end
  end


  @doc """
    ## Example:

      iex> Harmony.TxPool.txpool_inspect()
      {:ok, _}
  """
  @spec txpool_inspect :: {:ok, String.t} | {:error, String.t}
  def txpool_inspect do
    case Transport.send("txpool_inspect",[]) do
      {:ok, content} ->
        {:ok, content}
      {:error, reason} ->
        {:error, reason}
    end
  end

 @doc """
    ## Example:

      iex> Harmony.TxPool.txpool_status()
      {:ok, _}
  """
  @spec txpool_status :: {:ok, String.t} | {:error, String.t}
  def txpool_status do
    case Transport.send("txpool_status",[]) do
      {:ok, content} ->
        {:ok, dehex_map(content)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
    ## Example:
      
      iex> dehex_map(%{"pending" => "0x1bb98", "queued" => "0x6e1"})
      %{"pending" => 113560, "queued" => 1761}
  """
  @spec dehex_map(Map.t()) :: any()
  defp dehex_map(map) do
    Enum.reduce(
      Map.keys(map),
      %{}, 
      fn k, acc ->
        Map.put(acc, k, Ethereum.unhex(Map.get(map, k))) 
      end
    )
  end
  
end
