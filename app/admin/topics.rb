ActiveAdmin.register Topic do
  permit_params :name, :status, tag_ids: []
end
