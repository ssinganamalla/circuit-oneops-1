require 'json'
require 'fog/azurerm'
require 'chef'
require 'simplecov'
require File.expand_path('../../../azure_base/libraries/logger.rb', __FILE__)
SimpleCov.start

require File.expand_path('../../libraries/virtual_machine', __FILE__)

describe AzureCompute::VirtualMachineManager do
  before :each do
    workorder = File.read('virtual_machine_manager_spec.json')
    workorder_hash = JSON.parse(workorder)

    node = Chef::Node.new
    node.normal = workorder_hash
    node
    @virtual_machine = AzureCompute::VirtualMachine.new(credentials)
  end

  describe '# test create virtual machine' do
    # it 'returns virtual machines in a resource group' do
    #   allow(@virtual_machine.compute_service).to receive(:servers).and_return([])
    #   expect(@virtual_machine.get_resource_group_vms('test-rg')).to eq([])
    # end
    #
    # it 'raises exception' do
    #   allow(@virtual_machine.compute_service).to receive(:servers).and_raise(RuntimeError.new)
    #   expect { @virtual_machine.get_resource_group_vms('test-rg') }.to raise_error('no backtrace')
    # end
  end
end

