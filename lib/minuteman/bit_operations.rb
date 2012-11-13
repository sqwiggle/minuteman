class Minuteman
  module BitOperations
    BIT_OPERATION_PREFIX = "bitop"

    # Public: Checks for the existance of ids on a given set
    #
    #   ids - Array of ids
    #
    def include?(*ids)
      result = ids.map { |id| getbit(id) }
      result.size == 1 ? result.first : result
    end

    # Public: Resets the current key
    #
    def reset
      redis.rem(key)
    end

    # Public: Cheks for the amount of ids stored on the current key
    #
    def length
      redis.bitcount(key)
    end

    # Public: Calculates the NOT of the current key
    #
    def -@
      bit_operation("NOT", key)
    end
    alias :~@ :-@

    # Public: Calculates the substract of one set to another
    #
    #   timespan: Another BitOperations enabled class
    #
    def -(timespan)
      case timespan
      when Array
        bit_operation_with_data("MINUS", timespan)
      when TimeSpan
        self ^ (self & timespan)
      end
    end

    # Public: Calculates the XOR against another timespan
    #
    #   timespan: Another BitOperations enabled class
    #
    def ^(timespan)
      bit_operation("XOR", [key, timespan.key])
    end

    # Public: Calculates the OR against another timespan
    #
    #   timespan: Another BitOperations enabled class or an Array
    #
    def |(timespan)
      bit_operation("OR", [key, timespan.key])
    end
    alias :+ :|

    # Public: Calculates the AND against another timespan
    #
    #   timespan: Another BitOperations enabled class or an Array
    #
    def &(timespan)
      case timespan
      when Array
        bit_operation_with_data("AND", timespan)
      when TimeSpan
        bit_operation("AND", [key, timespan.key])
      end
    end

    private

    # Private: Helper to access the value a given bit
    #
    #   id: The bit
    #
    def getbit(id)
      redis.getbit(key, id) == 1
    end

    # Private: The destination key for the operation
    #
    #   type   - The bitwise operation
    #   events - The events to permuted
    #
    def destination_key(type, events)
      [
        Minuteman::PREFIX,
        BIT_OPERATION_PREFIX,
        type,
        events.join("-")
      ].join("_")
    end

    # Private: Returns an operable class given data
    #
    #   type - The operation
    #   data - The Array data
    #
    def bit_operation_with_data(type, data)
      normalized_data = Array(data)
      key = destination_key("data-#{type}", normalized_data)
      command = case type
                when "AND"    then :select
                when "MINUS"  then :reject
                end

      intersected_data = normalized_data.send(command) { |id| getbit(id) }

      intersected_data.each { |id| redis.setbit(key, id, 1) }
      BitOperationData.new(redis, key, intersected_data)
    end

    # Private: Executes a bit operation
    #
    #   type   - The bitwise operation
    #   events - The events to permuted
    #
    def bit_operation(type, events)
      key = destination_key(type, Array(events))
      redis.bitop(type, key, events)
      BitOperation.new(redis, key)
    end
  end

  # Public: The conversion of an array to an operable class
  #
  #   redis   - The Redis connection
  #   key     - The key where the result it's stored
  #   data    - The original data of the intersection
  #
  class BitOperationData < Struct.new(:redis, :key, :data)
    include BitOperations

    def to_ary
      data
    end

    def ==(other)
      other == data
    end
  end

  # Public: The result of intersecting results
  #
  #   redis   - The Redis connection
  #   key     - The key where the result it's stored
  #
  class BitOperation < Struct.new(:redis, :key)
    include BitOperations
  end
end
