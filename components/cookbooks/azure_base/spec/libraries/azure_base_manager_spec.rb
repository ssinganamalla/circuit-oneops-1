require 'chefspec'

require 'yaml'
require File.expand_path('../../../libraries/azure_base_manager.rb', __FILE__)

describe AzureBase::AzureBaseManager do
  before do
    @azure_credentials = YAML.load_file('spec/azure_credentials.yml')
  end

  context 'creating' do
    context 'all three parameters are passed in' do
      it 'uses those params to create creds' do
        base_mgr = AzureBase::AzureBaseManager.new(@azure_credentials['tenant_id'], @azure_credentials['client_id'], @azure_credentials['client_secret'])
        expect(base_mgr.token_creds).not_to be_nil
      end
    end
  end
end
