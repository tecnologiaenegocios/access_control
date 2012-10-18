require 'spec_helper'

describe "principal association" do
  include WithConstants

  let_constant(:ar_object_class) { new_class(:User, ActiveRecord::Base) }

  let(:ac_object_class)     { AccessControl::Principal }
  let(:ac_object_type_attr) { :subject_type }
  let(:ac_object_id_attr)   { :subject_id }

  def ac_object_from_ar_object(ar_object)
    AccessControl::Principal(ar_object)
  end

  def include_needed_modules(klass)
    klass.class_eval { include AccessControl::ActiveRecordSubject }
  end

  it_should_behave_like "any AccessControl object associated with an ActiveRecord::Base"
end
