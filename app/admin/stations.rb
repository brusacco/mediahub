# frozen_string_literal: true

ActiveAdmin.register Station do
  permit_params :name, :directory, :stream_url, :stream_status
end
