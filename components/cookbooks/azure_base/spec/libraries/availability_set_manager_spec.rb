require 'spec_helper'
require 'json'

require File.expand_path('../../../libraries/resource_group_manager.rb', __FILE__)
require File.expand_path('../../../libraries/availability_set_manager.rb', __FILE__)

describe AzureBase::AvailabilitySetManager do
  let(:node) do
    workorder = File.read('spec/workorders/compute.json')
    workorder_hash = JSON.parse(workorder)

    node = Chef::Node.new
    node.normal = workorder_hash
    node
  end

  let(:as_mgr) { AzureBase::AvailabilitySetManager.new(node) }
  let(:rg_mgr) { AzureBase::ResourceGroupManager.new(node) }

  describe '#initialize' do
    context 'when object is instantiated' do
      it 'creates compute_mgmt client' do
        expect(as_mgr.client).not_to be_nil
      end

      it 'contains subscription_id' do
        expect(as_mgr.client.subscription_id).not_to be_nil
      end
    end
  end

   describe '#get' do
    context 'when called' do
      it 'does not raise exception; returns nil or valid response' do
        expect { as_mgr.get }.not_to raise_error
      end
    end
  end

  describe '#add' do
    context 'when resource group does not exist' do
      it 'throws exception' do
        unless rg_mgr.exists?
          expect { as_mgr.add }.to raise_error('no backtrace')
        end
      end
    end

    context 'when resource group exists' do
      it 'creates the availability set' do
        rg_mgr.add
        as_mgr.add
        expect(as_mgr.get).not_to be_nil

        if rg_mgr.exists?
          rg_mgr.delete
        end
      end
    end

    context 'when resource group exists' do
      it 'does nothing and moves on' do
        unless as_mgr.get == nil
          expect { as_mgr.add }.not_to raise_error
        end
      end
    end
  end
end