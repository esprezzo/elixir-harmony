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
      rpcversion: 2,
      id: 0
    }

    harmony_host = case System.get_env("HARMONY_HOST") do
      nil ->
        # Logger.error "HARMONY_HOST ENVIRONMENT VARIABLE NOT SET. Using 127.0.0.1"
        "api.harmony.one"
      url ->
        # Logger.info "HARMONY_HOST ENVIRONMENT VARIABLE SET. Using #{url}"
        url
    end

    harmony_port = case System.get_env("HARMONY_PORT") do
      nil ->
        # Logger.error "HARMONY_PORT ENVIRONMENT VARIABLE NOT SET. Using 8545"
        "443"
      port ->
        # Logger.info "HARMONY_PORT ENVIRONMENT VARIABLE SET. Using #{port}"
        port
    end

    # infura_project_id = case System.get_env("INFURA_PROJECT_ID") do
    #   nil ->
    #     # Logger.error "INFURA_PROJECT_ID ENVIRONMENT VARIABLE NOT SET. Using standard form"
    #     nil
    #   p ->
    #     # Logger.info "INFURA_PROJECT_ID ENVIRONMENT VARIABLE SET. Using #{System.get_env("INFURA_PROJECT_ID")}"
    #     p
    # end

    # Requires --rpcvhosts=* on  aemon - TODO: Clean up move PORT to run script 
    daemon_host = case System.get_env("HARMONY_USE_SSL") do
      "false" -> 
        #   case infura_project_id do
        #     nil -> "https://" <> smart_chain_host <> ":" <> smart_chain_port
        #     key -> "https://" <> smart_chain_host <> "/" <> infura_project_id 
        #   end
        "http://" <> harmony_host <> ":" <> harmony_port
      _ -> 
        "https://" <> harmony_host <> ":" <> harmony_port
    end
    
    Logger.info "HARMONY DAEMON_HOST: #{daemon_host}"
    result = 
      __MODULE__.post!(daemon_host, enc)
      |> Map.get(:body)
      |> Map.get("result")

    result = 
      case dehex do
        true -> 
          __MODULE__.unhex(result)
        false ->
          result
      end    
    {:ok, result}
  end

  @spec unhex(String.t) :: String.t
  def unhex("0x"<>str) do
    str
  end
  def unhex(str) do
    str
  end
  
end
  