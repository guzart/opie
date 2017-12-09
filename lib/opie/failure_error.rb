module Opie
  class FailureError < StandardError
    attr_reader :failure

    def initialize(failure)
      super('Step failed')
      @failure = failure
    end
  end
end
