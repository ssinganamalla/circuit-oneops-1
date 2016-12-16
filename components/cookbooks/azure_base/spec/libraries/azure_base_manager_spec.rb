require 'chefspec'

require 'yaml'
require 'json'

require File.expand_path('../../../libraries/resource_group_manager.rb', __FILE__)
require File.expand_path('../../../libraries/logger.rb', __FILE__)
require File.expand_path('../../../libraries/utils.rb', __FILE__)

describe AzureBase::AzureBaseManager do
  let(:base_mgr) do
    workorder = File.read('spec/workorders/keypair.json')
    workorder_hash = JSON.parse(workorder)

    node = Chef::Node.new
    node.normal = workorder_hash

    AzureBase::AzureBaseManager.new(node)
  end

  describe '#initialize' do
    context 'when object is created' do
      it 'creds are not nil' do
        expect(base_mgr.creds).not_to be_nil
      end
    end
  end
end