# frozen_string_literal: true

ActiveAdmin.register Topic do
  permit_params :name, :status
end
