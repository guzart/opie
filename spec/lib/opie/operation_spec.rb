require 'spec_helper'

RSpec.describe Opie::Operation do
  let(:operation) { Class.new(Opie::Operation) }
  let(:op) { operation.new }

  before(:each) do
    allow(operation).to receive(:new).and_return(op)
  end

  describe '::new' do
    it 'registers the given parameters to the container "params"' do
      op = Opie::Operation.new(my_param: 'hello')
      expect(op.container['params'][:my_param]).to eq('hello')
    end

    it 'registers the given dependencies to the container' do
      op = Opie::Operation.new({}, other_dependency: 'mickey')
      expect(op.container['other_dependency']).to eq('mickey')
    end
  end

  describe '::call' do
    it 'initializes a new instance' do
      params = { boo: 'ya' }
      deps = { hello: 'hola' }
      expect(Opie::Operation).to receive(:new).with(params, deps).and_return(op)
      Opie::Operation.call(params, deps)
    end

    it 'executes the instance methods defined in ::step' do
      operation.class_exec { def hello() 'Hello' end }

      operation.step(:hello)
      expect(op).to receive(:hello)
      operation.call()
    end

    it 'stops step execution if one step returns FAIL' do
      operation.class_exec {
        def one() nil end
        def two() container.register('2', 2) end
        def three() fail end
        def four() container.register('4', 4) end
      }

      operation.step(:one)
      operation.step(:two)
      operation.step(:three)
      operation.step(:four)
      operation.call

      expect(op.container['2']).to eq(2)
      expect(op.container.key?('4')).to be false
    end

    it 'executes the steps in the defined order' do
      operation.class_exec {
        def two() container['out_count'] << 2 end
        def one() container.register('out_count', []) end
      }


      operation.step(:one)
      operation.step(:two)
      operation.call()
      expect(op.container['out_count']).to eq([2])
    end
  end

  describe 'success?' do
    it 'returns false if a step fails' do
      operation.class_exec {
        def one() fail end
        def two() 'wow' end
      }

      operation.step(:one)
      operation.step(:two)
      operation.call()
      expect(op).not_to be_success
    end

    it 'returns true if all steps succeed' do
      operation.class_exec {
        def one() 'yeah' end
        def two() 'awesome' end
      }

      operation.step(:one)
      operation.step(:two)
      operation.call
      expect(op).to be_success
    end
  end
end
