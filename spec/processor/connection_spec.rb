require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Pupa::Processor::Connection do
  describe '.new' do
    it 'should use MongoDB' do
      Pupa::Processor::Connection::MongoDBAdapter.should_receive(:new).with('localhost:27017', {}).and_call_original
      Pupa::Processor::Connection.new('mongodb', 'localhost:27017')
    end
  end
end