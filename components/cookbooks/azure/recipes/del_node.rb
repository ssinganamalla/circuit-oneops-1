require File.expand_path('../../../azure_base/libraries/logger.rb', __FILE__)
require 'fog/azurerm'

#set the proxy if it exists as a cloud var
Utils.set_proxy(node.workorder.payLoad.OO_CLOUD_VARS)

# delete the NIC from the platform specific resource group
def delete_nic(vm_client)
    start_time = Time.now.to_i
    nic_name = Utils.get_component_name("nic",vm_client.compute_ci_id)
    network_profile = AzureNetwork::NetworkInterfaceCard.new(vm_client.creds)
    network_profile.rg_name = vm_client.resource_group_name
    network_profile.get(nic_name).destroy
    end_time = Time.now.to_i
    duration = end_time - start_time
    OOLog.info("Deleting NIC '#{nic_name}' in #{duration} seconds")
end

#Delete public ip assocaited with the VM
def delete_publicip(vm_client)
  begin
    start_time = Time.now.to_i
    if ip_type == 'public'
      public_ip_name = Utils.get_component_name("publicip",vm_client.compute_ci_id)
      public_ip = AzureNetwork::PublicIp.new(vm_client.creds)
      public_ip.get(vm_client.resource_group_name, public_ip_name).destroy
    end
    end_time = Time.now.to_i
    duration = end_time - start_time
    OOLog.info("Deleting public ip '#{public_ip_name}' in #{duration} seconds")
 end
end

# invoke recipe to get credentials
include_recipe "azure::get_credentials"

# get platform resource group and availability set
include_recipe 'azure::get_platform_rg_and_as'

# delete the VM
  vm_client = AzureCompute::VirtualMachineManager.new(node)
  storage_account, vhd_uri, datadisk_uri = vm_client.delete_vm
  node.set["storage_account"] = storage_account
  node.set["vhd_uri"] = vhd_uri
  node.set["datadisk_uri"] = datadisk_uri

  # delete the NIC. A NIC is created with each VM, so we will delete the NIC when we delete the VM
  delete_nic(vm_client)

  # public IP must be deleted after the NIC.
  delete_publicip(vm_client)

  # delete the blobs
  # Delete both Page blob(vhd) and Block Blob from the storage account
  # Delete both osdisk and datadisk blob
  include_recipe "azure::del_blobs"

OOLog.info("Exiting azure delete compute")
