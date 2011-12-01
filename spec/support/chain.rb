def combine_values(options)
  size = options.values.inject(1) { |s, a| s * a.size }
  (0..(size - 1)).inject([]) do |r, n|
    freeze = size
    row = options.inject({}) do |h, (key, values)|
      l = values.size
      freeze /= l
      index = (n / freeze) % l
      h[key] = values[index]
      h
    end
    if block_given?
      r << yield(row)
    else
      r << row
    end
  end
end

def items_from(collection)
  CollectionAttributeFilter.new(collection)
end

class CollectionAttributeFilter
  include Enumerable

  def initialize(collection)
    @collection = collection
    @attributes = {}
  end

  def with(attributes)
    @attributes = attributes; self
  end

  def each
    filtered_collection do |item|
      yield item
    end
  end

  def filtered_collection
    @filtered_collection ||= @collection.each do |item|
      if @attributes.all? { |attribute, value| item.send(attribute) == value }
        yield item
      end
    end
  end
end
