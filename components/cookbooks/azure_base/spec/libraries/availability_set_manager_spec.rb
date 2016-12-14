require 'chefspec'

require 'yaml'
require File.expand_path('../../../libraries/availability_set_manager.rb', __FILE__)

describe AzureBase::AvailabilitySetManager do
  before do
    @azure_credentials = YAML.load_file('spec/azure_credentials.yml')
  end

  context 'creating' do
    context 'all three parameters are passed in' do
      it 'uses those params to create creds' do
        # avail_mgr = AzureBase::AvailabilitySetManager.new(@tenant_id, @client_id, @client_secret)
        # expect(base_mgr.creds).not_to be_nil
      end
    end
  end
end
