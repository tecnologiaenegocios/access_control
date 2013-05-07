# On ruby 1.9+, the Array#flatten method calls #to_ary on each of the array's
# elements, and expects them to raise NoMethodError if they can't be converted
# into an array. RSpec 1.x mocks aren't prepared for that, and will raise the
# 'unexpected method' error instead of NoMethodError.
#
# The issue is solved on rspec 2.x:
# https://github.com/rspec/rspec-mocks/issues/31

if Spec::VERSION::MAJOR > 1
  raise "This monkey patch isn't needed on rspec > 1.x, please remove it"
end

class Spec::Mocks::Mock
  def to_a
    nil
  end
  def to_ary
    nil
  end
end
