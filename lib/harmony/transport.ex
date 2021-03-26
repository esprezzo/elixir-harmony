defmodule Harmony.Transport do
  require Logger
  require IEx

  use Tesla

  plug Tesla.Middleware.Headers, [
  ]
  plug Tesla.Middleware.JSON

  @doc false
  @spec send(method :: String.t, params :: map) :: {:ok, map} | {:error, String.t}
  def send(method, params \\ %{}, dehex \\ true) do
    
    enc = %{
      method: method, 
      params: params, 
      id: 0
    }

    smart_chain_host = case System.get_env("HARMONY_HOST") do
      nil ->
        # Logger.error "HARMONY_HOST ENVIRONMENT VARIABLE NOT SET. Using 127.0.0.1"
        "127.0.0.1"
      url ->
        # Logger.info "HARMONY_HOST ENVIRONMENT VARIABLE SET. Using #{url}"
        url
    end

    smart_chain_port = case System.get_env("HARMONY_PORT") do
      nil ->
        Logger.error "HARMONY_PORT ENVIRONMENT VARIABLE NOT SET. Using 8545"
        8545
      port ->
        # Logger.info "HARMONY_PORT ENVIRONMENT VARIABLE SET. Using #{port}"
        port
    end

    infura_project_id = case System.get_env("INFURA_PROJECT_ID") do
      nil ->
        # Logger.error "INFURA_PROJECT_ID ENVIRONMENT VARIABLE NOT SET. Using standard form"
        nil
      p ->
        # Logger.info "INFURA_PROJECT_ID ENVIRONMENT VARIABLE SET. Using #{System.get_env("INFURA_PROJECT_ID")}"
        p
    end

    # Requires --rpcvhosts=* on  aemon - TODO: Clean up move PORT to run script
 
    daemon_host = case System.get_env("HARMONY_USE_SSL") do
      "true" -> 
        case infura_project_id do
          nil -> "https://" <> smart_chain_host <> ":" <> smart_chain_port
          key -> "https://" <> smart_chain_host <> "/" <> infura_project_id 
        end
      _ -> "http://" <> smart_chain_host <> ":" <> smart_chain_port
    end
    
    # Logger.info "HARMONY DAEMON_HOST: #{daemon_host}"
    result = 
      __MODULE__.post!(daemon_host, enc)
      |> Map.get(:body)
      |> Map.get("result")
    # Logger.warn "#{inspect result}"
    
    result = 
      case dehex do
        true -> 
          __MODULE__.unhex(result)
        false ->
          result
      end    
    {:ok, result}
  end

  # @doc """
  # Transport macro function to strip Harmony 0x for easier decoding later.

  # ## Example:
        
  #     iex> __MODULE__.unhex("0x557473f9c6029a2d4b7ac8a37aa407414db6820faf1f7fa48b3b038f857d5aac")
  #     "557473f9c6029a2d4b7ac8a37aa407414db6820faf1f7fa48b3b038f857d5aac"
  # """
  @doc false
  @spec unhex(String.t) :: String.t
  def unhex("0x"<>str) do
    str
  end
  def unhex(str) do
    str
  end
  
end
  