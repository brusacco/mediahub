# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :set_paper_trail_whodunnit
  before_action :user_topics

  protected

  def user_for_paper_trail
    admin_user_signed_in? ? current_admin_user.try(:id) : 'Unknown user'
  end

  private

  def user_topics
    return unless user_signed_in?

    @topicos = current_user.topics.where(status: true)
  end  
end
