require 'fog/azurerm'

module AzureCompute
  class VirtualMachine

    attr_reader :compute_service

    def initialize(credentials)
      @compute_service = Fog::Compute::AzureRM.new(credentials)
    end

    def get_resource_group_vms(resource_group_name)
      begin
        OOLog.info("Fetcing virtual machines in '#{resource_group_name}'")
        start_time = Time.now.to_i
        virtual_machines = @compute_service.servers(resource_group: resource_group_name)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue RuntimeError => e
        OOLog.fatal("Error getting VMs in resource group: #{resource_group_name}. Error Message: #{e.message}")
      end

      OOLog.info("operation took #{duration} seconds")
      virtual_machines
    end

    def get(resource_group_name, vm_name)
      begin
        OOLog.info("Fetching VM '#{vm_name}' in '#{resource_group_name}' ")
        start_time = Time.now.to_i
        virtual_machine = @compute_service.servers.get(resource_group_name, vm_name)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue RuntimeError => e
        OOLog.fatal("Error fetching VM: #{vm_name}. Error Message: #{e.message}")
      end

      OOLog.info("operation took #{duration} seconds")
      virtual_machine
    end

    def start(resource_group_name, vm_name)
      begin
        OOLog.info("Starting VM: #{vm_name} in resource group: #{resource_group_name}")
        start_time = Time.now.to_i
        virtual_machine = @compute_service.servers.get(resource_group_name, vm_name)
        response = virtual_machine.start
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue RuntimeError => e
        OOLog.fatal("Error starting VM. #{vm_name}. Error Message: #{e.message}")
      end

      OOLog.info("VM started in #{duration} seconds")
      response
    end

    def restart(resource_group_name, vm_name)
      begin
        OOLog.info("Restarting VM: #{vm_name} in resource group: #{resource_group_name}")
        start_time = Time.now.to_i
        virtual_machine = @compute_service.servers.get(resource_group_name, vm_name)
        response = virtual_machine.restart
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue RuntimeError => e
        OOLog.fatal("Error restarting VM. #{vm_name}. Error Message: #{e.message}")
      end

      OOLog.info("operation took #{duration} seconds")
      response
    end

    def power_off(resource_group_name, vm_name)
      begin
        OOLog.info("Power off VM: #{vm_name} in resource group: #{resource_group_name}")
        start_time = Time.now.to_i
        virtual_machine = @compute_service.servers.get(resource_group_name, vm_name)
        response = virtual_machine.power_off
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue RuntimeError => e
        OOLog.fatal("Error powering off VM. #{vm_name}. Error Message: #{e.message}")
      end

      OOLog.info("operation took #{duration} seconds")
      response
    end
  end
end