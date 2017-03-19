require 'dry-container'

module Opie
  class Operation
    attr_reader :container

    def initialize(params = {}, dependencies = {})
      @container = Dry::Container.new
      @container.register('params', params)
      dependencies.each { |k, v| @container.register(k, v) }
    end

    class << self
      def call(*args)
        instance = self.new(*args)
        instance.send(:execute_steps, step_list)
        instance
      end

      def step(step)
        add_step(step)
      end

      private

      def add_step(value)
        @steps ||= []
        @steps << value
      end

      def step_list
        @steps ||= []
      end
    end

    def fail
      'fail'
    end

    # def []=(key, value)
    #   container.register(key, value)
    # end
    # result, container

    def success?
      !failure?
    end

    def failure?
      @failure
    end

    private

    def execute_steps(steps)
      @failure = steps.find { |m| send(m) == 'fail' }
    end
  end
end
