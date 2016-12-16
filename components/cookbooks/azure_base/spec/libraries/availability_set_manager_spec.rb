require 'spec_helper'
require 'json'

require File.expand_path('../../../libraries/availability_set_manager.rb', __FILE__)

describe AzureBase::AvailabilitySetManager do
  let(:rg_mgr) do
    workorder = File.read('spec/workorders/compute.json')
    workorder_hash = JSON.parse(workorder)

    node = Chef::Node.new
    node.normal = workorder_hash

    AzureBase::AvailabilitySetManager.new(node)
  end

  describe '#initialize' do
    context 'when object is instantiated' do
      it 'creates rg_mgmt client' do
        expect(rg_mgr.client).not_to be_nil
      end
    end
  end

  describe '#exists?' do
    context 'when called' do
      it 'returns Boolean' do
        is_bool = false
        response = rg_mgr.exists?
        if response.is_a?(TrueClass) || response.is_a?(FalseClass)
          is_bool = true
        end

        expect(is_bool).to be true
      end
    end
  end

  describe '#add' do
    context 'when resource group does not exist' do
      it 'creates the resource group' do
        unless rg_mgr.exists?
          rg_mgr.add
          expect(rg_mgr.exists?).to be true
        end
      end
    end

    context 'when resource group exists' do
      it 'does nothing and moves on' do
        if rg_mgr.exists?
          rg_mgr.add
          expect(rg_mgr.exists?).to be true
        end
      end
    end
  end

  describe '#delete' do
    context 'when resource group exists' do
      it 'deletes the resource group' do
        if rg_mgr.exists?
          rg_mgr.delete
          expect(rg_mgr.exists?).to be false
        end
      end
    end

    context 'when resource group does not exist' do
      it 'throws exception' do
        unless rg_mgr.exists?
          expect { rg_mgr.delete }.to raise_error('no backtrace')
        end
      end
    end
  end
end