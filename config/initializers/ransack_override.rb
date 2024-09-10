# config/initializers/ransack_override.rb

ActsAsTaggableOn::Tagging.class_eval do
  def self.ransackable_attributes(auth_object = nil)
    column_names
  end

  def self.ransackable_associations(auth_object = nil)
    reflect_on_all_associations.map(&:name).map(&:to_s)
  end
end
