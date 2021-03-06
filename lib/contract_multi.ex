defmodule Harmony.ContractMulti do
    use GenServer
    require Logger
    require IEx
    alias Harmony.ABI

    # Client
    @spec start_link(atom()) :: {:ok, pid()}
    @doc "Begins the Contract process to manage all interactions with smart contracts"
    def start_link(process_name) do
      GenServer.start_link(__MODULE__, %{filters: %{}}, name: process_name)
    end

    @spec register(atom(), atom(), list()) :: :ok
    @doc "Registers the contract with the ContractManager process. Only :abi is required field."
    def register(process_name, name, contract_info) do
      GenServer.cast(process_name, {:register, {name, contract_info}})
    end

    @spec uninstall_filter(atom(), binary()) :: :ok
    @doc "Uninstalls the filter, and deletes the data associated with the filter id"
    def uninstall_filter(process_name, filter_id) do
      GenServer.cast(process_name, {:uninstall_filter, filter_id})
    end

    @spec at(atom(), atom(), binary()) :: :ok
    @doc "Sets the address for the contract specified by the name argument"
    def at(process_name, name, address) do
      GenServer.cast(process_name, {:at, {name, address}})
    end

    @spec address(binary(), atom()) :: {:ok, binary()}
    @doc "Returns the current Contract GenServer's address"
    def address(process_name, name) do
      GenServer.call(process_name, {:address, name})
    end

    @spec call(binary(), atom(), atom(), list()) :: {:ok, any()}
    @doc "Use a Contract's method with an eth_call"
    def call(process_name, contract_name, method_name, args \\ []) do
      GenServer.call(process_name, {:call, {contract_name, method_name, args}}, 20000)
    end

    @spec send(binary(), atom(), atom(), list(), map()) :: {:ok, binary()}
    @doc "Use a Contract's method with an eth_sendTransaction"
    def send(process_name, contract_name, method_name, args, options) do
      GenServer.call(process_name, {:send, {contract_name, method_name, args, options}})
    end

    @spec tx_receipt(binary(), atom(), binary()) :: map()
    @doc "Returns a formatted transaction receipt for the given transaction hash(id)"
    def tx_receipt(process_name, contract_name, tx_hash) do
      GenServer.call(process_name, {:tx_receipt, {contract_name, tx_hash}})
    end

    @spec filter(binary(), atom(), binary(), map()) :: {:ok, binary()}
    @doc "Installs a filter on the Harmony node. This also formats the parameters, and saves relevant information to format event logs."
    def filter(process_name, contract_name, event_name, event_data \\ %{}) do
      GenServer.call(
        process_name,
        {:filter, {contract_name, event_name, event_data}}
      )
    end

    @spec get_filter_logs(atom(), binary()) :: {:ok, list()}
    @doc "Using saved information related to the filter id, event logs are formatted properly"
    def get_filter_logs(process_name, filter_id) do
      GenServer.call(
        process_name,
        {:get_filter_logs, filter_id},
        100000000
      )
    end

    @spec get_logs(atom(), binary(), binary(), binary()) :: {:ok, list()}
    @doc "Using saved information related to the filter id, event logs are formatted properly"
    def get_logs(process_name, contract_name, event_name, event_data \\ %{}) do
      GenServer.call(
        process_name,
        {:get_logs, {contract_name, event_name, event_data}},
        100000000
      )
    end

    @spec get_filter_changes(binary(), binary()) :: {:ok, list()}
    @doc "Using saved information related to the filter id, event logs are formatted properly"
    def get_filter_changes(process_name, filter_id) do
      GenServer.call(
        process_name,
        {:get_filter_changes, filter_id}
      )
    end

    # Start Server
    def init(state) do
      {:ok, state}
    end

    defp data_signature_helper(name, fields) do
      non_indexed_types = Enum.map(fields, &Map.get(&1, "type"))
      Enum.join([name, "(", Enum.join(non_indexed_types, ","), ")"])
    end

    defp topic_types_helper(fields) do
      if length(fields) > 0 do
        Enum.map(fields, fn field ->
          "(#{field["type"]})"
        end)
      else
        []
      end
    end

    defp init_events(abi) do
      
      events =
        Enum.filter(abi, fn {_, v} ->
          v["type"] == "event"
        end)

      names_and_signature_types_map =
        Enum.map(events, fn {name, v} ->
          types = Enum.map(v["inputs"], &Map.get(&1, "type"))
          signature = Enum.join([name, "(", Enum.join(types, ","), ")"])

          encoded_event_signature = "0x#{Harmony.encode_abi_event(signature)}"

          indexed_fields =
            Enum.filter(v["inputs"], fn input ->
              input["indexed"]
            end)

          indexed_names =
            Enum.map(indexed_fields, fn field ->
              field["name"]
            end)

          non_indexed_fields =
            Enum.filter(v["inputs"], fn input ->
              !input["indexed"]
            end)

          non_indexed_names =
            Enum.map(non_indexed_fields, fn field ->
              field["name"]
            end)

          data_signature = data_signature_helper(name, non_indexed_fields)

          event_attributes = %{
            signature: data_signature,
            non_indexed_names: non_indexed_names,
            topic_types: topic_types_helper(indexed_fields),
            topic_names: indexed_names
          }

          {{encoded_event_signature, event_attributes}, {name, encoded_event_signature}}
        end)

      signature_types_map =
        Enum.map(names_and_signature_types_map, fn {signature_types, _} ->
          signature_types
        end)

      names_map =
        Enum.map(names_and_signature_types_map, fn {_, names} ->
          names
        end)

      [
        events: Enum.into(signature_types_map, %{}),
        event_names: Enum.into(names_map, %{})
      ]
    end

    # Helpers
    def deploy_helper(bin, abi, args) do
      constructor_arg_data =
        if arguments = args[:args] do
          constructor_abi =
            Enum.find(abi, fn {_, v} ->
              v["type"] == "constructor"
            end)

          if constructor_abi do
            {_, constructor} = constructor_abi
            input_types = Enum.map(constructor["inputs"], fn x -> x["type"] end)
            types_signature = Enum.join(["(", Enum.join(input_types, ","), ")"])

            arg_count = Enum.count(arguments)
            input_types_count = Enum.count(input_types)

            if input_types_count != arg_count do
              raise "Number of provided arguments to constructor is incorrect. Was given #{
                      arg_count
                    } args, looking for #{input_types_count}."
            end
            bin <> (Harmony.encode_abi_data(types_signature, arguments) |> Base.encode16(case: :lower))
          else
            # IO.warn("Could not find a constructor")
            bin
          end
        else
          bin
        end

      gas = Harmony.encode_option(args[:options][:gas])

      tx = %{
        from: args[:options][:from],
        data: "0x#{constructor_arg_data}",
        gas: gas
      }

      # Return the tx immediately here
      # Recursively wait for receipt in outer function
      {:ok, tx_hash} = Harmony.eth_send([tx])
    end

    def eth_call_helper(address, abi, method_name, args) do
     
      result =
        Harmony.eth_call([
          %{
            to: address,
            data: "0x#{Harmony.encode_abi_method_call(abi, method_name, args)}"
          }
        ])
      
      case result do
        {:ok, data} ->   
          case data do
            nil -> 
              {:ok, 1}
            d ->  
              try do             
                ret = Harmony.decode_abi_output(abi, method_name, data)
                ([:ok] ++ ret ) |> List.to_tuple()
              rescue MatchError ->
                Logger.warn "IN ERROR"
                {:ok, "CONTRACT_ERROR"}
              end
              
            false ->
              IEx
          end
        {:error, err} -> {:error, err}
      end
    end

    def eth_send_helper(address, abi, method_name, args, options) do
      encoded_options =
        Harmony.encode_abi_options(
          options,
          [:gas, :gasPrice, :value, :nonce]
        )

      Harmony.eth_send([
        Map.merge(
          %{
            to: address,
            data: "0x#{Harmony.encode_abi_method_call(abi, method_name, args)}"
          },
          Map.merge(options, encoded_options)
        )
      ])
    end

    defp register_helper(contract_info) do
      if contract_info[:abi] do
        contract_info ++ init_events(contract_info[:abi])
      else
        raise "ABI not provided upon initialization"
      end
    end

    # Options checkers
    defp check_option(nil, error_atom), do: {:error, error_atom}
    defp check_option([], error_atom), do: {:error, error_atom}
    defp check_option([head | _tail], _atom) when head != nil, do: {:ok, head}
    defp check_option([_head | tail], atom), do: check_option(tail, atom)
    defp check_option(value, _atom), do: {:ok, value}

    # Casts
    def handle_cast({:at, {name, address}}, state) do
      contract_info = state[name]
      {:noreply, Map.put(state, name, contract_info ++ [address: address])}
    end

    def handle_cast({:register, {name, contract_info}}, state) do
      {:noreply, Map.put(state, name, register_helper(contract_info))}
    end

    def handle_cast({:uninstall_filter, filter_id}, state) do
      Harmony.uninstall_filter(filter_id)
      {:noreply, Map.put(state, :filters, Map.delete(state[:filters], filter_id))}
    end

    # Calls
    defp filter_topics_helper(event_signature, event_data, topic_types, topic_names) do
      topics =
        if is_map(event_data[:topics]) do
          Enum.map(topic_names, fn name ->
            event_data[:topics][String.to_atom(name)]
          end)
        else
          event_data[:topics]
        end

      if topics do
        formatted_topics =
          Enum.map(0..(length(topics) - 1), fn i ->
            topic = Enum.at(topics, i)

            if topic do
              if is_list(topic) do
                topic_type = Enum.at(topic_types, i)

                Enum.map(topic, fn t ->
                  "0x" <> (Harmony.encode_abi_data(topic_type, [t]) |> Base.encode16(case: :lower))
                end)
              else
                topic_type = Enum.at(topic_types, i)
                "0x" <> (Harmony.encode_abi_data(topic_type, [topic]) |> Base.encode16(case: :lower))
              end
            else
              topic
            end
          end)

        [event_signature] ++ formatted_topics
      else
        [event_signature]
      end
    end

    def from_block_helper(event_data) do
      if event_data[:fromBlock] do
        new_from_block =
          if Enum.member?(["latest", "earliest", "pending"], event_data[:fromBlock]) do
            event_data[:fromBlock]
          else
            Harmony.encode_abi_data("(uint256)", [event_data[:fromBlock]])
          end

        Map.put(event_data, :fromBlock, new_from_block)
      else
        event_data
      end
    end

    defp param_helper(event_data, key) do
      if event_data[key] do
        new_param =
          if Enum.member?(["latest", "earliest", "pending"], event_data[key]) do
            event_data[key]
          else
              # (Harmony.encode_abi_data("(uint256)", [event_data[key]]) |> Base.encode16(case: :lower))
              Harmony.to_hex(event_data[key])
          end

        Map.put(event_data, key, new_param)
      else
        event_data
      end
    end

    defp event_data_format_helper(event_data) do
      event_data
      |> param_helper(:fromBlock)
      |> param_helper(:toBlock)
      |> Map.delete(:topics)
    end

    def get_event_attributes(state, contract_name, event_name) do
      contract_info = state[contract_name]
      contract_info[:events][contract_info[:event_names][event_name]]
    end

    defp extract_non_indexed_fields(data, names, signature) do
      Enum.zip(names, Harmony.decode_abi_event(data, signature)) |> Enum.into(%{})
    end

    defp format_log_data(log, event_attributes) do
      non_indexed_fields =
        extract_non_indexed_fields(
          Map.get(log, "data"),
          event_attributes[:non_indexed_names],
          event_attributes[:signature]
        )
      non_indexed_fields = 
        case Map.get(non_indexed_fields, "pair") do
          nil ->
            non_indexed_fields 
          add ->
            decoded_address = ABI.decode_address_binary(add)
            Map.put(non_indexed_fields, "pair", decoded_address)
        end
    
      indexed_fields =
        if length(log["topics"]) > 1 do
          [_head | tail] = log["topics"]
          decoded_topics =
            Enum.map(0..(length(tail) - 1), fn i ->
              topic_type = Enum.at(event_attributes[:topic_types], i)
              topic_data = Enum.at(tail, i)
              Harmony.decode_abi_data(topic_type, topic_data)
            end)
          Enum.zip(event_attributes[:topic_names], decoded_topics) |> Enum.into(%{})
        else
          %{}
        end

      new_data = Map.merge(indexed_fields, non_indexed_fields)
      Map.put(log, "data", new_data)
    end

    def handle_call({:filter, {contract_name, event_name, event_data}}, _from, state) do
      contract_info = state[contract_name]

      event_signature = contract_info[:event_names][event_name]
      topic_types = contract_info[:events][event_signature][:topic_types]
      topic_names = contract_info[:events][event_signature][:topic_names]

      topics = filter_topics_helper(event_signature, event_data, topic_types, topic_names)
      
      payload =
        Map.merge(
          %{address: contract_info[:address], topics: topics},
          event_data_format_helper(event_data)
        )
      # Logger.warn "Event payload #{inspect payload}"
      
      {:ok, filter_id} = Harmony.new_filter(payload)
   
      updated_state = 
        Map.put(
          state,
          :filters,
          Map.put(state[:filters], filter_id, %{
            contract_name: contract_name,
            event_name: event_name
          })
        )
  
      {:reply, {:ok, filter_id}, updated_state}
    end

    def handle_call({:get_filter_logs, filter_id}, _from, state) do
      
      filter_unhex = 
        case filter_id do
          "0x" <> n -> n
          n -> n
        end 

      filter_info = Map.get(state[:filters], filter_unhex)
      Logger.warn(filter_info)
      event_attributes =
        get_event_attributes(state, filter_info[:contract_name], filter_info[:event_name])
      
      {:ok, logs} = Harmony.get_filter_logs(filter_id)
      
   
      formatted_logs =
        if logs && logs != [] do
          Enum.map(logs, fn log ->
            # Logger.warn "event_attributes: #{inspect event_attributes}"
            # event_attributes: %{non_indexed_names: ["value"], signature: "Transfer(uint256)", topic_names: ["from", "to"], topic_types: ["(address)", "(address)"]}
            # Logger.warn "log: #{inspect log}"
            formatted_log =
              Enum.reduce(
                [
                  Harmony.abi_keys_to_decimal(log, [
                    "blockNumber",
                    "logIndex",
                    "transactionIndex",
                    "transactionLogIndex"
                  ]),
                  format_log_data(log, event_attributes)
                ],
                &Map.merge/2
              )
            formatted_log
          end)
        else
          logs
        end
      {:reply, {:ok, formatted_logs}, state}
    end

   def handle_call({:get_logs, {contract_name, event_name, event_data}}, _from, state) do
      contract_info = state[contract_name]

      event_signature = contract_info[:event_names][event_name]
      topic_types = contract_info[:events][event_signature][:topic_types]
      topic_names = contract_info[:events][event_signature][:topic_names]

      topics = filter_topics_helper(event_signature, event_data, topic_types, topic_names)
      
      payload =
        Map.merge(
          %{address: contract_info[:address], topics: topics},
          event_data_format_helper(event_data)
        )
    
      event_attributes =
        get_event_attributes(state, contract_info[:address], event_name)
            
      {:ok, logs} = Harmony.get_logs(payload)
      
   
      formatted_logs =
        if logs && logs != [] do
          Enum.map(logs, fn log ->
            # Logger.warn "event_attributes: #{inspect event_attributes}"
            # Logger.warn "log: #{inspect log}"
            formatted_log =
              Enum.reduce(
                [
                  Harmony.abi_keys_to_decimal(log, [
                    "blockNumber",
                    "logIndex",
                    "transactionIndex",
                    "transactionLogIndex"
                  ]),
                  format_log_data(log, event_attributes)
                ],
                &Map.merge/2
              )
            formatted_log
          end)
        else
          logs
        end
      {:reply, {:ok, formatted_logs}, state}
    end

    def handle_call({:address, name}, _from, state) do
      {:reply, state[name][:address], state}
    end

    def handle_call({:call, {contract_name, method_name, args}}, _from, state) do
      contract_info = state[contract_name]
      
      with {:ok, address} <- check_option(contract_info[:address], :missing_address) do
        result = eth_call_helper(address, contract_info[:abi], Atom.to_string(method_name), args)
        {:reply, result, state}
      else
        err -> {:reply, err, state}
      end
    end

    def handle_call({:send, {contract_name, method_name, args, options}}, _from, state) do
      contract_info = state[contract_name]

      with {:ok, address} <- check_option(contract_info[:address], :missing_address),
           {:ok, _} <- check_option(options[:from], :missing_sender),
           {:ok, _} <- check_option(options[:gas], :missing_gas) do
        result =
          eth_send_helper(
            address,
            contract_info[:abi],
            Atom.to_string(method_name),
            args,
            options
          )

        {:reply, result, state}
      else
        err -> {:reply, err, state}
      end
    end

    # catch weird ssl error
    def handle_info({:ssl_closed, _}, state) do
      {:noreply, state}
    end
   
  end