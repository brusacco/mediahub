# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @videos = Video.all
  end
end
