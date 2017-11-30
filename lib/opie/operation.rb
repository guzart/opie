module Opie
  class Operation
    attr_reader :failure, :output

    def call(input = nil)
      execute_steps(input)
      self
    end

    def failure?
      !success?
    end

    def success?
      failure.nil?
    end

    def failures
      [failure].compact
    end

    class << self
      def call(input = nil)
        new.call(input)
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
        next_step = method(name)
        next_input = if next_input.is_a?(Array) && (next_step.arity == next_input.count || next_step.arity == -1)
                       public_send(name, *next_input)
                     else
                       public_send(name, next_input)
                     end
        failure?
      end

      @output = next_input if success?
    end

    def fail(type, data = nil)
      @failure = Failure.new(type, data)
    end
  end
end
