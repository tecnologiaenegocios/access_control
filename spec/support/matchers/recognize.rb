Spec::Matchers.define :recognize do |object|
  match do |target|
    target.recognizes?(object)
  end
end

