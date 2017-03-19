require 'dry-container'

module Opie
  class Operation
    FAIL = '__STEP_FAILED__'.freeze

    attr_reader :error

    def call(input = nil)
      execute_steps(input)
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
      arg = input
      self.class.step_list.each do |name|
        arg = public_send(name, arg)
      end
    end

    def failure(type, data = nil)
      @error = { type: type, data: data }
    end
  end
end
