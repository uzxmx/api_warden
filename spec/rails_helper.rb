ENV["RAILS_ENV"] ||= 'test'

require 'spec_helper'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'rspec/rails'

class AuthenticationApplication < Rails::Application
  config.cache_classes = true
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false  

  config.secret_key_base = SecureRandom.uuid

  config.middleware.delete Rails::Rack::Logger
end

class AuthenticationController < ActionController::Base
  before_action :ward_by_user!, only: :sign_out

  def sign_in
    uid = 1
    tokens = generate_tokens_for_user(uid, uid)
    render json: { uid: uid, access_token: tokens.first, refresh_token: tokens.last }
  end

  def sign_out
    current_user_authentication.sign_out
    render json: { succ: true }
  end

  def refresh_access_token
    sign_in if validate_refresh_token_for_user!
  end
end

class ResourceController < ActionController::Base
  before_action :ward_by_user!, except: :unprotected

  def unprotected
    render json: { msg: "I'm unprotected!" }
  end  

  def protected
    render json: { msg: "I'm protected!" }
  end
end

Rails.application.routes.draw do
  controller :authentication do
    post :sign_in
    delete :sign_out
    post :refresh_access_token
  end

  controller :resource, path: 'resource' do
    get :unprotected
    get :protected
  end
end
Rails.application.routes.disable_clear_and_finalize = true

module ApiWarden::RSpecHelpers
  def self.sign_in(example)
    example.instance_exec do
      post '/sign_in'
      @auth = JSON.parse(response.body, symbolize_names: true)
      @headers = {
        'X-User-Id': @auth[:uid],
        'X-User-Access-Token': @auth[:access_token]        
      }
      @refresh_headers = {
        'X-User-Id': @auth[:uid],
        'X-User-Refresh-Token': @auth[:refresh_token]
      }
    end
  end
end
