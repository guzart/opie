module Opie
  class Failure < StandardError
    attr_reader :data

    def initialize(message)
      @data = message
      super(message)
    end
  end
end
