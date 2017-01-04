require 'fog/azurerm'
module AzureNetwork
  # Operations of Load Balancer Class
  class LoadBalancer
    # include Azure::ARM::Network
    # include Azure::ARM::Network::Models

    attr_reader :client, :subscription_id

    def initialize(credentials, subscription_id)
      Fog::Network::AzureRM.new(
          tenant_id: credentials[:tenant_id],
          client_id: credentials[:client_id],
          client_secret: credentials[:client_secret],
          subscription_id: subscription_id
      )
    end

    def get_subscription_load_balancers
      begin
        puts('Fetching load balancers from subscription')
        start_time = Time.now.to_i
        result = @azure_network_service.load_balancers
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue MsRestAzure::AzureOperationError => e
        puts('Error fetching load balancers from subscription')
        puts("Error response: #{e.response}")
        puts("Error body: #{e.body}")
        result = Azure::ARM::Network::Models::LoadBalancerListResult.new
        return result
      end
      puts("operation took #{duration} seconds")
      return result
    end

    def get_resource_group_load_balancers(resource_group_name)
      begin
        puts("Fetching load balancers from '#{resource_group_name}'")
        start_time = Time.now.to_i
        result = @azure_network_service.load_balancers(resource_group: resource_group_name)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue MsRestAzure::AzureOperationError => e
        puts("Error fetching load balancers from '#{resource_group_name}'")
        puts("Error Response: #{e.response}")
        puts("Error Body: #{e.body}")
        result = Azure::ARM::Network::Models::LoadBalancerListResult.new
        return result
      end
      puts("operation took #{duration} seconds")
      return result
    end

    def get(resource_group_name, load_balancer_name)
      begin
        puts("Fetching load balancer '#{load_balancer_name}' from '#{resource_group_name}' ")
        start_time = Time.now.to_i
        result = @azure_network_service.load_balancers.get(resource_group_name, load_balancer_name)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue MsRestAzure::AzureOperationError => e
        OOLog.info("Error getting LoadBalancer '#{load_balancer_name}' in ResourceGroup '#{resource_group_name}' ")
        OOLog.info("Error Code: #{e.body['error']['code']}")
        OOLog.info("Error Message: #{e.body['error']['message']}")

        result = Azure::ARM::Network::Models::LoadBalancer.new
        return result
      end
      puts("operation took #{duration} seconds")
      return result
    end

    def create_update(resource_group_name, load_balancer_name, lb)
      begin
        puts("Creating/Updating load balancer '#{load_balancer_name}' in '#{resource_group_name}' ")
        start_time = Time.now.to_i
        result = @client.load_balancers.create_or_update(resource_group_name, load_balancer_name, lb)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue  MsRestAzure::AzureOperationError => e
        msg = "Error Code: #{e.body['error']['code']}"
        msg += "Error Message: #{e.body['error']['message']}"
        OOLog.fatal("Error creating/updating load balancer '#{load_balancer_name}'. #{msg} ")
      rescue => ex
        OOLog.fatal("Error creating/updating load balancer '#{load_balancer_name}'. #{ex.message} ")
      end
      puts("operation took #{duration} seconds")
      return result
    end

    def delete(resource_group_name, load_balancer_name)
      begin
        puts("Deleting load balancer '#{load_balancer_name}' from '#{resource_group_name}' ")
        start_time = Time.now.to_i
        result = @client.load_balancers.delete(resource_group_name, load_balancer_name)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue  MsRestAzure::AzureOperationError => e
        msg = "Error Code: #{e.body['error']['code']}"
        msg += "Error Message: #{e.body['error']['message']}"
        OOLog.fatal("Error deleting load balancer '#{load_balancer_name}'. #{msg} ")
      rescue => ex
        OOLog.fatal("Error deleting load balancer '#{load_balancer_name}'. #{ex.message} ")
      end
      puts("operation took #{duration} seconds")
      return result
    end

    # ===== Static Methods =====

    def self.create_frontend_ipconfig(frontend_name, public_ip, subnet)
      # Frontend IP configuration, a Load balancer can include one or more frontend IP addresses,
      # otherwise known as a virtual IPs (VIPs). These IP addresses serve as ingress for the traffic.
      if public_ip.nil?
        frontend_ipconfig = {
          name: frontend_name,
          private_ipallocation_method: 'Static',
          private_ipaddress: '10.1.2.5',
          subnet_id: subnet.id
        }
      else
        frontend_ipconfig = {
          name: frontend_name,
          private_ipallocation_method: 'Dynamic',
          public_ipaddress_id: public_ip.id
        }
      end
      frontend_ipconfig
    end

    def self.create_backend_address_pool(backend_address_pool_name)
      # Backend address pool, these are IP addresses associated with the
      # virtual machine Network Interface Card (NIC) to which load will be distributed.
      backend_address_pool_name
    end

    def self.create_probe(probe_name, protocol, port, interval_secs, num_probes, request_path)
      # Probes, probes enable you to keep track of the health of VM instances.
      # If a health probe fails, the VM instance will be taken out of rotation automatically.
      {
          name: probe_name,
          protocol: protocol,
          request_path: request_path,
          port: port,
          interval_in_seconds: interval_secs,
          number_of_probes: num_probes
      }
    end

    def self.create_lb_rule(lb_rule_name, load_distribution, protocol, frontend_port, backend_port, probe_id, frontend_ipconfig_id, backend_address_pool_id)
      # Load Balancing Rule: a rule property maps a given frontend IP and port combination to a set
      # of backend IP addresses and port combination.
      # With a single definition of a load balancer resource, you can define multiple load balancing rules,
      # each rule reflecting a combination of a frontend IP and port and backend IP and port associated with VMs.

      {
          name: lb_rule_name,
          frontend_ip_configuration_id: frontend_ipconfig_id,
          backend_address_pool_id: backend_address_pool_id,
          probe_id: probe_id,
          protocol: protocol,
          frontend_port: frontend_port,
          backend_port: backend_port,
          enable_floating_ip: false,
          idle_timeout_in_minutes: 5,
          load_distribution: load_distribution
      }
    end

    def self.create_inbound_nat_rule(nat_rule_name, protocol, frontend_ipconfig_id, frontend_port, backend_port)
      # Inbound NAT rules, NAT rules defining the inbound traffic flowing through the frontend IP
      # and distributed to the back end IP.
      {
          name: nat_rule_name,
          frontend_ip_configuration_id: frontend_ipconfig_id,
          protocol: protocol,
          frontend_port: frontend_port,
          backend_port: backend_port
      }
    end

    def self.get_lb(resource_group_name, lb_name, location, frontend_ip_configs, backend_address_pools, lb_rules, nat_rules, probes)
      {
          name: lb_name,
          resource_group: resource_group_name,
          location: location,
          frontend_ip_configurations: frontend_ip_configs,
          backend_address_pool_names: backend_address_pools,
          load_balancing_rules: lb_rules,
          inbound_nat_rules: nat_rules,
          probes: probes
      }
    end
  end
end
