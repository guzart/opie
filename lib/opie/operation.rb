# TODO: The API should be something like:
# case result.failure
# when ValidationError then handle_validation(result.failure.errors)
# when AuthorizationError then handle_authorization(result.failure.message)
module Opie
  class Operation
    attr_reader :failure, :output, :context

    def call(input = nil, context = nil)
      @context = context
      execute_steps(input)
      self
    end

    def failure?
      !success?
    end

    def success?
      !failure
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
    rescue Failure => error
      @failure = error
    end

    def step_list
      self.class.step_list
    end

    def fail_step(message = 'failure')
      raise Failure, message
    end
  end
end
