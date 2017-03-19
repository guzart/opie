require 'spec_helper'

RSpec.describe Opie::Operation do
  let(:operation_klass) { Class.new(Opie::Operation) }
  let(:operation) { operation_klass.new }

  before(:each) do
    allow(operation_klass).to receive(:new).and_return(operation)
  end

  describe '::step' do
    it 'defines a method to be called when running the operation' do
      add_operation_method(:alpha)

      operation_klass.step(:alpha)
      expect(operation).to receive(:alpha)

      run_operation
    end
  end

  describe '#call' do
    it 'uses the first argument as the parameter for the first step' do
      add_step(:alpha)

      expect(operation).to receive(:alpha).with(message: 'hello')

      operation.call(message: 'hello')
    end

    it 'executes the step methods in the order they are defined' do
      add_step(:beta)
      add_step(:alpha)

      expect(operation).to receive(:beta).ordered
      expect(operation).to receive(:alpha).ordered

      operation.call
    end

    it 'uses the output of one step as the input for the next' do
      add_step(:alpha) { |input| input + ' world' }
      add_step(:beta) { |msg| msg + '!' }

      expect(operation).to receive(:beta).with('hello world')

      operation.call('hello')
    end
  end

  describe '::call' do
    it 'initializes a new instance and invokes #call' do
      operation = double('operation')
      expect(operation_klass).to receive(:new).and_return(operation)
      expect(operation).to receive(:call)

      operation_klass.call
    end
  end

  # HELPERS

  # Defines a method in the Operation class
  def add_operation_method(name, &block)
    block ||= ->(_) { nil }
    operation_klass.class_exec do
      define_method(name, &block)
    end
  end

  # Adds a step to the operation with an optional definition.
  def add_step(name, &block)
    operation_klass.step(name)
    add_operation_method(name, &block)
  end

  def add_failed_step(name)
    add_step(name) do
      [Opie::Operation::FAIL]
    end
  end

  # Runs the contextual operation
  def run_operation(*args)
    operation_klass.call(*args)
  end
end
