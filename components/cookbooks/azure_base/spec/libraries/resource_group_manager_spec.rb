require 'chefspec'

require 'yaml'
require File.expand_path('../../../libraries/resource_group_manager.rb', __FILE__)

describe AzureBase::ResourceGroupManager do
  before do
    @azure_credentials = YAML.load_file('spec/azure_credentials.yml')
    rg_mgr = AzureBase::ResourceGroupManager.new(@azure_credentials, @azure_credentials['master_rg_eus2'], client_id, @client_secret)
  end

  context 'creating rg_mgr' do
    context 'all three parameters are passed in' do
      it 'uses those params to create resource group manager' do
        expect(rg_mgr.client).not_to be_nil
      end

      it 'creates a resource group and deletes it'
        rg_mgr.add
        expect(rg_mgr.exists?).to be true
        rg_mgr.delete
        expect(rg_mgr.exists?).to be false
      end
    end
  end
end
