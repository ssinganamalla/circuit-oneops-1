require 'simplecov'
require 'rest-client'
SimpleCov.start
require File.expand_path('../../libraries/network_security_group.rb', __FILE__)
require 'fog/azurerm'

describe AzureNetwork::NetworkSecurityGroup do
  before do
    token_provider = MsRestAzure::ApplicationTokenProvider.new('<TENANT_ID>', '<CLIENT_ID>', 'CLIENT_SECRET')
    credentials = MsRest::TokenCredentials.new(token_provider)
    subscription = '<SUBSCRIPTION>'
    @network_security_group = AzureNetwork::NetworkSecurityGroup.new(credentials, subscription)
  end

  describe '#get' do
    it 'gets network security group successfully' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :get).and_return(true)
      expect(@network_security_group.get('<RESOURCE_GROUP>', '<NSG_NAME>')).to_not eq(false)
    end
    it 'raises AzureOperationError exception while getting network security group' do
      exception = MsRestAzure::AzureOperationError.new('Errors')
      ex_values = []
      allow(exception).to receive_message_chain(:body, :values) { ex_values.push( {'code' => 'ResourceNotFound'} ) }
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :get)
        .and_raise(exception)

      expect(@network_security_group.get('<RESOURCE_GROUP>', '<NSG_NAME>')).to eq(nil)
    end
    it 'raises AzureOperationError exception while getting network security group' do
      exception = MsRestAzure::AzureOperationError.new('Errors')
      allow(exception).to receive_message_chain(:body, :values) { ['x', 'y'] }
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :get)
                                                           .and_raise(exception)

      expect { @network_security_group.get('<RESOURCE_GROUP>', '<NSG_NAME>') }.to raise_error('no backtrace')
    end
    it 'raises exception while getting network security group' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :get)
        .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @network_security_group.get('<RESOURCE_GROUP>', '<NSG_NAME>') }.to raise_error('no backtrace')
    end
  end






  describe '#create_or_update' do
    it 'creates application gateway successfully' do
      file_path = File.expand_path('gateway_response.json', __dir__)
      file = File.open(file_path)
      gateway_response = file.read
      allow(@gateway.application_gateway).to receive_message_chain(:gateways, :create).and_return(gateway_response)
      expect(@gateway.create_or_update('east-us', false)).to_not eq(nil)
    end
    it 'raises AzureOperationError exception while creating application gateway' do
      allow(@gateway.application_gateway).to receive_message_chain(:gateways, :create)
                                                 .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect { @gateway.create_or_update('east-us', true) }.to raise_error('no backtrace')
    end
    it 'raises exception while creating application gateway' do
      allow(@gateway.application_gateway).to receive_message_chain(:gateways, :create)
                                                 .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @gateway.create_or_update('east-us', true) }.to raise_error('no backtrace')
    end
  end

  describe '#delete' do
    it 'deletes application gateway successfully' do
      allow(@gateway.application_gateway).to receive_message_chain(:gateways, :get, :destroy).and_return(true)
      delete_gw = @gateway.delete

      expect(delete_gw).to_not eq(false)
    end
    it 'raises AzureOperationError exception' do
      allow(@gateway.application_gateway).to receive_message_chain(:gateways, :get, :destroy)
                                                 .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect { @gateway.delete }.to raise_error('no backtrace')
    end
    it 'raises exception while deleting application gateway' do
      allow(@gateway.application_gateway).to receive_message_chain(:gateways, :get, :destroy)
                                                 .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @gateway.delete }.to raise_error('no backtrace')
    end
  end
end
