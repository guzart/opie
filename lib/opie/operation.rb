module Opie
  class Operation
    FAIL = '__STEP_FAILED__'.freeze

    attr_reader :failure, :output, :context

    def call(input = nil, context = nil)
      @context = context
      execute_steps(input)
      self
    end

    def failure?
      failure
    end

    def success?
      !failure?
    end

    def failures
      [failure].compact
    end

    class << self
      def call(input = nil, context = nil)
        new.call(input, context)
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
      args = [name, input]
      args = args.push(context) if method(name).arity == 2
      public_send(*args)
    end

    def fail(type, data = nil)
      @failure = Failure.new(type, data)
    end
  end
end
