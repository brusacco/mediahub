# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check
  
  post 'home/merge_videos', to: 'home#merge_videos'
  
  get 'stations/show'
  resources :topics, only: [:show]
  resources :tags, only: [:show]
  resources :videos, only: [:show]

  # Deploy changes from GitHub
  post 'deploy', to: 'home#deploy'
  # Defines the root path route ("/")
  root 'home#index'
end
