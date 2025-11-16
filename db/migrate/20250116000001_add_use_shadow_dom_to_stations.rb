# frozen_string_literal: true

class AddUseShadowDomToStations < ActiveRecord::Migration[7.1]
  def change
    add_column :stations, :use_shadow_dom, :boolean, default: false
  end
end

