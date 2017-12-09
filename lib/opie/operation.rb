module Opie
  class Operation
    attr_reader :failure, :output

    def call(input = nil, &block)
      execute_steps(input, &block)
      yield self if block_given?
      self
    end

    def failure?
      !success?
    end

    def on_fail
      yield failure if block_given? && failure?
    end

    def success?
      failure.nil?
    end

    def on_success
      yield output if block_given? && success?
    end

    def failures
      [failure].compact
    end

    class << self
      def call(input = nil, &block)
        new.call(input, &block)
      end

      def step(name)
        add_step(name)
      end

      def step_list
        @steps ||= []
      end

      private

      def add_step(name)
        @steps ||= []
        @steps << name
      end
    end

    private

    def execute_steps(input)
      step_list = self.class.step_list

      next_input = input
      step_list.find do |name|
        next_input = execute_step(name, next_input)
        failure?
      end

      @output = next_input if success?
    end

    def execute_step(name, input)
      next_step = method(name)
      if input.is_a?(Array) && (next_step.arity == input.count || next_step.arity == -1)
        public_send(name, *input)
      else
        public_send(name, input)
      end
    rescue FailureError => e
      @failure = e.failure
    end

    def fail(type, data = nil)
      raise FailureError, Failure.new(type, data)
    end
  end
end
