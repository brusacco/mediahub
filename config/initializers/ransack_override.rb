# config/initializers/ransack_override.rb

ActsAsTaggableOn::Tagging.class_eval do
  def self.ransackable_attributes(_auth_object = nil)
    column_names
  end

  def self.ransackable_associations(_auth_object = nil)
    reflect_on_all_associations.map(&:name).map(&:to_s)
  end
end
