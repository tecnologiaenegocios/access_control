Spec::Matchers.define :include_only do |*items|

  match do |target|
    includes_all_items = items.all? do |item|
      target.include?(item)
    end
    has_same_cardinality = items.size == target.size

    includes_all_items and has_same_cardinality
  end

end
