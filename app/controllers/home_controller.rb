# frozen_string_literal: true

# Home controller
class HomeController < ApplicationController
  def index
    @videos = Video.where.not(transcription: nil).order(posted_at: :desc).limit(5)
  end
end
