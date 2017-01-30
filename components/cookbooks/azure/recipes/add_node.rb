require 'fog/azurerm'

total_start_time = Time.now.to_i

#set the proxy if it exists as a cloud var
Utils.set_proxy(node['workorder']['payLoad']['OO_CLOUD_VARS'])

# get platform resource group and availability set
include_recipe 'azure::get_platform_rg_and_as'

resource_group_name = node['platform-resource-group']
OOLog.info('Resource group name: ' + resource_group_name)

vm_manager = AzureCompute::VirtualMachineManager.new(node)
compute_service = vm_manager.compute_service

credentials = {
    tenant_id: compute_service[:tenant_id],
    client_secret: compute_service[:client_secret],
    client_id: compute_service[:client_id],
    subscription_id: compute_service[:subscription]
}

vm_manager.creds = credentials
# must do this until all is refactored to use the util above.
node.set['azureCredentials'] = credentials

# check whether the VM with given name exists already
node.set['VM_exists'] = vm_manager.check_vm_exists?

# create the vm
vm_manager.create_or_update_vm

# set the ip type
node.set['ip_type'] = vm_manager.ip_type

# set the initial user
node.set['initial_user'] = vm_manager.initial_user

# set the ip on the node as the private ip
node.set['ip'] = vm_manager.private_ip
# write the ip information to stdout for the inductor to pick up and use.

ip_type = vm_manager.ip_type
ci_id = vm_manager.compute_ci_id

if ip_type == 'private'
  puts "***RESULT:private_ip=#{node['ip']}"
  puts "***RESULT:public_ip=#{node['ip']}"
  puts "***RESULT:dns_record=#{node['ip']}"
else
  puts "***RESULT:private_ip=#{node['ip']}"
end

# for public deployments we need to get the public ip address after the vm
# is created
if ip_type == 'public'
  # need to get the public ip that was assigned to the VM
  begin
    # get the pip name
    public_ip_name = Utils.get_component_name('publicip', ci_id)
    OOLog.info("public ip name: #{public_ip_name}")

    pip = AzureNetwork::PublicIp.new(credentials)
    publicip_details = pip.get(resource_group_name, public_ip_name)
    pubip_address = publicip_details.ip_address
    OOLog.info("public ip found: #{pubip_address}")
    # set the public ip and dns record on stdout for the inductor
    puts "***RESULT:public_ip=#{pubip_address}"
    puts "***RESULT:dns_record=#{pubip_address}"
    node.set['ip'] = pubip_address
  rescue MsRestAzure::AzureOperationError => e
    OOLog.fatal("Error getting pip from Azure: #{e.body}")
  rescue => ex
    OOLog.fatal("Error getting pip from Azure: #{ex.message}")
  end
end

include_recipe 'compute::ssh_port_wait'

rfcCi = node['workorder']['rfcCi']
nsPathParts = rfcCi['nsPath'].split("/")
customer_domain = node['customer_domain']
owner = node['workorder']['payLoad']['Assembly'][0]['ciAttributes']['owner'] || 'na'
node.set['max_retry_count_add'] = 30

mgmt_url = "https://#{node['mgmt_domain']}"
if node.has_key?('mgmt_url') && !node['mgmt_url'].empty?
  mgmt_url = node['mgmt_url']
end

metadata = {
  "owner" => owner,
  "mgmt_url" =>  mgmt_url,
  "organization" => node['workorder']['payLoad']['Organization'][0]['ciName'],
  "assembly" => node['workorder']['payLoad']['Assembly'][0]['ciName'],
  "environment" => node['workorder']['payLoad']['Environment'][0]['ciName'],
  "platform" => node['workorder']['box']['ciName'],
  "component" => node['workorder']['payLoad']['RealizedAs'][0]['ciId'].to_s,
  "instance" => node['workorder']['rfcCi']['ciId'].to_s
}

puts "***RESULT:metadata=#{JSON.dump(metadata)}"
total_end_time = Time.now.to_i
duration = total_end_time - total_start_time
OOLog.info("Total Time for azure::add_node recipe is #{duration} seconds")
