module Opie
  class Operation
    attr_reader :failure, :output

    def call(input = nil, &block)
      execute_steps(input, &block)
      if block_given?
        return yield self
      end
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
        @steps ||= []
        @steps << name
      end

      def step_list
        @steps ||= []
      end
    end

    private

    def execute_steps(input)
      step_list = self.class.step_list

      next_input = input
      step_list.each do |name|
        next_input = if name.is_a?(String) || name.is_a?(Symbol)
                       execute_step(name, next_input)
                     else
                       execute_operation(name, next_input)
                     end
      end
      @output = next_input if success?
    rescue FailureError => e
      @failure = e.failure
    end

    def execute_step(name, input)
      next_step = method(name)
      if input.is_a?(Array) && (next_step.arity == input.count || next_step.arity == -1)
        public_send(name, *input)
      else
        public_send(name, input)
      end
    end

    def execute_operation(klass, input)
      klass.call(input) do |res|
        res.on_success do |output|
          return output
        end
        res.on_fail do |err|
          raise FailureError, err
        end
      end
    end

    def fail(type, data = nil)
      raise FailureError, Failure.new(type, data)
    end
  end
end
