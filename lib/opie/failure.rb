module Opie
  class Failure
    attr_reader :data, :type

    def initialize(type, data = nil)
      @type = type
      @data = data
    end

    def ==(other)
      type == other.type && data == other.data
    end

    def hash
      [type, (data || '').to_sym].hash
    end
  end
end
