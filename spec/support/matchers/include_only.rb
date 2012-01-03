Spec::Matchers.define :include_only do |*items|

  match do |target|
    includes_all_items = items.all? do |item|
      target.include?(item)
    end
    has_same_cardinality = items.count == target.count

    includes_all_items and has_same_cardinality
  end

end
