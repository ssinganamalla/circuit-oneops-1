require File.expand_path('../../../azure_base/libraries/resource_group_manager.rb', __FILE__)
require File.expand_path('../../../azure/libraries/virtual_machine.rb', __FILE__)
require 'chef'
require 'fog/azurerm'

class Datadisk
  attr_accessor :device_maps,
                :rg_name_persistent_storage,
                :storage_account_name,
                :instance_name,
                :compute_client,
                :storage_client,
                :virtual_machine_lib

  def initialize(creds, storage_account_name, rg_name_persistent_storage, instance_name, device_maps)
    @storage_account_name = storage_account_name
    @rg_name_persistent_storage = rg_name_persistent_storage
    @instance_name = instance_name
    @device_maps = device_maps

    @virtual_machine_lib = AzureCompute::VirtualMachine.new(creds)
    @compute_client = Fog::Compute::AzureRM.new(creds)
    @storage_client = Fog::Storage::AzureRM.new(creds)
    storage_access_key = get_storage_access_key

    credentials = {
      tenant_id: creds['tenant_id'],
      client_id: creds['client_id'],
      client_secret: creds['client_secret'],
      subscription_id: creds['subscription_id'],
      azure_storage_account_name: @storage_account_name,
      azure_storage_access_key: storage_access_key
    }

    @storage_client = Fog::Storage::AzureRM.new(credentials)
  end

  def create
    begin
      @device_maps.each do |dev_vol|
        slice_size = dev_vol.split(":")[3]
        dev_id = dev_vol.split(":")[4]
        component_name = dev_vol.split(":")[2]
        dev_name = dev_id.split('/').last
        OOLog.info("slice_size :#{slice_size}, dev_id: #{dev_id}")
        vhd_blobname = "https://#{@storage_account_name}.blob.core.windows.net/vhds/#{@storage_account_name}-#{component_name}-datadisk-#{dev_name}.vhd"
        if check_blob_exist(vhd_blobname)
          OOLog.fatal('disk name exists already')
        else
          container = 'vhds'
          return @storage_client.create_page_blob(container, vhd_blobname, slice_size)
        end
      end
    rescue MsRestAzure::AzureOperationError => e
      OOLog.fatal("Failed to create the disk: #{e.message}")
    rescue Exception => ex
      OOLog.fatal("Failed to create the disk: #{ex.message}")
    end
  end

  def attach
    i = 1
    dev_id = ''
    OOLog.info("Subscription id is: #{@subscription}")
    @device_maps.each do |dev_vol|
      slice_size = dev_vol.split(':')[3]
      dev_id = dev_vol.split(':')[4]
      component_name = dev_vol.split(":")[2]
      OOLog.info("slice_size :#{slice_size}, dev_id: #{dev_id}")
      vm = @virtual_machine_lib.get(@rg_name_persistent_storage, @instance_name)

      #Add a data disk
      flag = false
      (vm.data_disks).each do |disk|
        if disk.lun == i - 1
          flag = true
        end
      end
      if flag
        i = i + 1
        next
      end
      vm.data_disks.push(build_storage_profile(i, component_name, slice_size, dev_id))
      attach_disk_to_vm(vm)
      OOLog.info("Adding #{dev_id} to the dev list")
      i = i + 1
    end
    dev_id
  end

  #attach disk to the VM
  def attach_disk_to_vm(vm)
    start_time = Time.now.to_i
    OOLog.info('Attaching Storage disk ....')
    begin
      @virtual_machine_lib.create_update(get_hash_from_object(vm))
    rescue MsRestAzure::AzureOperationError => e
      OOLog.debug(e.body.inspect)
      if e.body.to_s =~ /InvalidParameter/ && e.body.to_s =~ /already exists/
        OOLog.debug('The disk is already attached')
      else
        OOLog.fatal(e.body)
      end
    rescue Exception => ex
      OOLog.fatal("Error Attaching Storage disk: #{ex.message}")
    end
    end_time = Time.now.to_i
    duration = end_time - start_time
    OOLog.info("Storage Disk attached #{duration} seconds")
    OOLog.info("VM: #{vm.name} UPDATED!!!")
    true
  end

  #Get storage account name to use
  def get_storage_account_name(vm)
    storage_account_name=((vm.os_disk_vhd_uri).split('.')[0]).split('//')[1]
    OOLog.info('storage account to use:' + storage_account_name)
    storage_account_name
  end

  # build the storage profile object to add a new datadisk
  def build_storage_profile(disk_no, component_name, slice_size, dev_id)
    data_disk = Fog::Storage::AzureRM::DataDisk.new
    dev_name = dev_id.split('/').last
    data_disk.name = "#{component_name}-datadisk-#{dev_name}"
    OOLog.info('data_disk:' + data_disk.name)
    data_disk.lun = disk_no - 1
    OOLog.info('data_disk lun:' + data_disk.lun.to_s)
    data_disk.disk_size_gb = slice_size
    data_disk.vhd_uri = "https://#{@storage_account_name}.blob.core.windows.net/vhds/#{@storage_account_name}-#{component_name}-datadisk-#{dev_name}.vhd"
    OOLog.info('data_disk uri:'+data_disk.vhd_uri)
    data_disk.caching = Fog::ARM::Compute::Models::CachingTypes::ReadWrite
    blob_name = "#{@storage_account_name}-#{component_name}-datadisk-#{dev_name}.vhd"
    is_new_disk_or_old = check_blob_exist(blob_name)
    if is_new_disk_or_old
      data_disk.create_option = Fog::ARM::Compute::Models::DiskCreateOptionTypes::Attach
    else
      data_disk.create_option = Fog::ARM::Compute::Models::DiskCreateOptionTypes::Empty
    end
    data_disk
  end

  def check_blob_exist(blob_name)
    container = 'vhds'
    begin
      blob_prop = @storage_client.get_blob_properties(container, blob_name)
    rescue Exception => e
      OOLog.debug(e.message)
      OOLog.debug(e.message.inspect)
      return false
    end
    Chef::Log.info("Blob properties #{blob_prop.inspect}")
    if blob_prop != nil
      OOLog.info('disk exists')
      true
    end
  end

  def get_storage_access_key
    OOLog.info('Getting storage account keys ....')
    begin
      storage_account_keys = @storage_client.get_storage_access_keys(@rg_name_persistent_storage, @storage_account_name)
    rescue MsRestAzure::AzureOperationError => e
      OOLog.fatal(e.body)
    rescue Exception => ex
      OOLog.fatal(ex.message)
    end
    OOLog.info('Storage_account_keys : ' + storage_account_keys.inspect)
    key2 = storage_account_keys[1]
    raise unless key2.key_name == 'key2'
    key2.value
  end

  def delete_datadisk
    @device_maps.each do |dev|
      dev_id = dev.split(':')[4]
      storage_account_name = dev.split(':')[1]
      component_name = dev.split(':')[2]
      dev_name = dev_id.split('/').last
      blob_name = "#{storage_account_name}-#{component_name}-datadisk-#{dev_name}.vhd"
      status = delete_disk_by_name(blob_name)
      if status == 'DiskUnderLease'
        detach
        delete_disk_by_name(blob_name)
      end
    end
    true
  end

  def delete_disk_by_name(blob_name)
    container = 'vhds'
    # Delete a Blob
    begin
      delete_result = false
      retry_count = 20
      begin
        if retry_count > 0
          OOLog.info("Trying to delete the disk page (page blob):#{blob_name} ....")
          delete_result = @storage_client.delete_blob(container, blob_name)
        end
        retry_count = retry_count-1
      end until delete_result || retry_count == 0
      if delete_result != true && retry_count == 0
        OOLog.debug("Error in deleting the disk (page blob):#{blob_name}")
        return 'failure'
      end
    rescue MsRestAzure::AzureOperationError => e
      if e.type == 'LeaseIdMissing'
        OOLog.debug("Failed to delete the disk because there is currently a lease on the blob. Make sure to delete all volumes on the disk attached before detaching disk from VM")
        return 'DiskUnderLease'
      end
      OOLog.fatal("Failed to delete the disk: #{e.body}")
    rescue Exception => ex
      OOLog.fatal("Failed to delete the disk: #{ex.message}")
    end
    OOLog.info("Successfully deleted the disk(page blob):#{blob_name}")
    'success'
  end

  def detach
    i = 1
    vm = @virtual_machine_lib.get(@rg_name_persistent_storage, @instance_name)
    @device_maps.each do |dev_vol|
      dev_id = dev_vol.split(':')[4]
      component_name = dev_vol.split(':')[2]
      dev_name = dev_id.split('/').last
      diskname = "#{component_name}-datadisk-#{dev_name}"
      #Detach a data disk
      (vm.data_disks).each do |disk|
        if disk.name == diskname
          OOLog.info('deleting disk at lun:'+(disk.lun).to_s + " dev:#{dev_name} ")
          vm.data_disks.delete_at(i-1)
        end
      end
    end
    unless vm.nil?
      OOLog.info('updating VM with these properties' + vm.inspect)
      update_vm_properties(vm)
    end
  end

  #detach disk from the VM

  def update_vm_properties(vm)
    begin
      start_time = Time.now.to_i
      my_vm = @virtual_machine_lib.create_update(get_hash_from_object(vm))
      end_time = Time.now.to_i
      duration = end_time - start_time
      OOLog.info("Storage Disk detached #{duration} seconds")
      OOLog.info("VM: #{my_vm.name} UPDATED!!!")
      return true
    rescue MsRestAzure::AzureOperationError => e
      OOLog.fatal(e.body)
    rescue Exception => ex
      OOLog.fatal(ex.message)
    end
  end

  def get_hash_from_object(object)
    hash = {}
    object.instance_variables.each { |attr| hash[attr.to_s.delete('@')] = object.instance_variable_get(attr) }
    hash
  end
end
