require 'spec_helper'

RSpec.describe Opie::Operation do
  let(:operation_klass) { Class.new(Opie::Operation) }
  let(:operation) { operation_klass.new }

  before(:each) do
    allow(operation_klass).to receive(:new).and_return(operation)
  end

  describe '::step' do
    it 'defines a method to be called when running the operation' do
      define_step(:alpha)

      operation_klass.step(:alpha)
      expect(operation).to receive(:alpha)

      run_operation
    end

    it 'accepts another operation' do
      boxing_operation_klass = Class.new(Opie::Operation)
      boxing_operation_klass.class_exec do
        step :array_box

        def array_box(input)
          [input]
        end
      end

      add_step(boxing_operation_klass)
      expect(run_operation('hello').output).to eq(['hello'])
    end
  end

  describe '#call' do
    it 'uses the first argument as the parameter for the first step' do
      add_step(:alpha)

      expect(operation).to receive(:alpha).with(message: 'hello')

      operation.call(message: 'hello')
    end

    it 'accepts a context as a second parameter' do
      ctx = { current_user: 'admin' }
      add_step(:alpha)

      operation.call('hello', ctx)

      expect(operation.context).to be(ctx)
    end

    it 'passes the context to the method if the method takes a second argument' do
      add_step_definition(:alpha) do
        def alpha(_input, context)
          raise 'Context was not given' if context[:current_user] != 'admin'
        end
      end

      operation.call('hello', current_user: 'admin')
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

    it 'returns the newly created instance' do
      expect(operation.call('hello')).to be_an_instance_of(operation_klass)
    end

    it 'stops execution when a step fails' do
      add_step(:alpha)
      add_failed_step(:beta)
      add_step(:charlie)

      expect(operation).to receive(:beta).and_call_original
      expect(operation).not_to receive(:charlie)

      run_operation
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

  describe '#success?' do
    it 'returns true when all steps are successful' do
      add_step(:alpha) { |_| nil }
      add_step(:beta) { |_| nil }

      result = run_operation
      expect(result).to be_success
    end

    it 'returns false when an step fails' do
      add_step(:alpha) { |_| nil }
      add_failed_step(:beta)

      result = run_operation
      expect(result).not_to be_success
    end
  end

  describe '#failure?' do
    it 'returns true when a steps fail' do
      add_step(:alpha) { |_| nil }
      add_failed_step(:beta) { |_| nil }

      result = run_operation
      expect(result).to be_failure
    end

    it 'returns true when a step raises an error' do
      add_step(:alpha) { |_| raise 'Oh no!' }
      result = run_operation
      expect(result).to be_failure
    end

    it 'returns false when none of the step fail' do
      add_step(:alpha) { |_| nil }
      add_step(:beta)

      result = run_operation
      expect(result).not_to be_failure
    end
  end

  describe '#output' do
    it 'returns the return value of the last step' do
      add_step(:alpha) { |_| 'wow' }
      add_step(:beta) { |_| 'oh boy' }

      result = run_operation
      expect(result.output).to eq('oh boy')
    end

    it 'returns nil if the operation failed' do
      add_step(:alpha) { |_| 'wow' }
      add_failed_step(:beta)
      add_step(:charlie) { |_| 'something else' }

      expect(run_operation.output).to be_nil
    end
  end

  describe 'helper methods' do
    describe '#fail_step' do
      it 'is a private method' do
        expect(operation).not_to respond_to(:fail_step)
      end

      it 'assigns the first parameter as the failure.data' do
        add_step(:alpha) do |_input|
          fail_step(:not_found)
        end

        run_operation
        expect(operation.failure.data).to eq(:not_found)
      end

      it 'optionally takes error data' do
        add_step(:alpha) { |_input| fail_step(:oopsy) }
        expect { run_operation }.not_to raise_error
      end

      it 'makes #failure? return true' do
        add_step(:alpha) { |_input| fail_step(:oopsy) }
        run_operation
        expect(operation).to be_failure
      end

      it 'makes #success? return false' do
        add_step(:alpha) { |_input| fail_step(:oopsy) }
        run_operation
        expect(operation).not_to be_success
      end
    end
  end

  # HELPERS

  def define_step(name = nil, &block)
    return if name.is_a?(Class)

    if name
      block ||= ->(_) { nil }
      operation_klass.class_exec do
        define_method(name, &block)
      end
    else
      operation_klass.class_exec(&block)
    end
  end

  def add_step_definition(name, &block)
    operation_klass.step(name)
    define_step(&block)
  end

  # Adds a step to the operation with an optional definition.
  def add_step(name, &block)
    operation_klass.step(name)
    define_step(name, &block)
  end

  def add_failed_step(name)
    add_step(name) do |_|
      fail_step
    end
  end

  # Runs the contextual operation
  def run_operation(*args)
    operation_klass.call(*args)
  end
end
