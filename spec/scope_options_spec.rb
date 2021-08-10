require 'rails_helper'

class ResourceController < ActionController::Base
  def me
    render json: { id: current_user[:id], name: current_user[:name] }
  end

  def value_for_access_token
    render json: JSON.parse(current_user_authentication.value_for_access_token)
  end

  def value_for_refresh_token
    if current_user_authentication.value_for_refresh_token
      render json: JSON.parse(current_user_authentication.value_for_refresh_token)
    else
      render json: {}, status: 404
    end
  end
end

Rails.application.routes.draw do
  controller :resource, path: :resource do
    get :me, :value_for_access_token, :value_for_refresh_token
  end
end

RSpec.describe 'Scope options', :type => :request do
  before do
    ApiWarden.configure do |config|
      config.redis = ConnectionPool.new(:timeout => 1, :size => 1) { Redis.new }
    end
  end

  describe '#load_owner' do
    context 'without the option' do
      before do
        ApiWarden.ward_by(:users)

        ApiWarden::RSpecHelpers.sign_in(self)
      end

      it 'raises errors when invoking current_user' do
        expect { get '/resource/me', nil, @headers }.to raise_error(NameError)
      end

      after do
        ApiWarden.remove_ward_by(:users)
      end
    end

    context 'with the option' do
      before do
        ApiWarden.ward_by(:users, load_owner: proc { |id, value, auth|
          { id: id, name: "foo" }
        })

        ApiWarden::RSpecHelpers.sign_in(self)
      end

      it 'renders user info' do
        get '/resource/me', nil, @headers

        expect(response.body).to include_json(id: 1, name: "foo")
      end

      after do
        ApiWarden.remove_ward_by(:users)
      end
    end
  end

  describe '#expire_time' do
    before do
      Redis.new.flushall

      ApiWarden.ward_by(:users, expire_time_for_access_token: 3600.seconds, expire_time_for_refresh_token: 7200.seconds)

      allow(Time).to receive(:now).and_return(0)

      ApiWarden::RSpecHelpers.sign_in(self)
    end

    it 'can refresh when refresh token does not expire' do
      allow(Time).to receive(:now).and_return(3599)
      get '/resource/protected', nil, @headers
      expect(response.body).to include_json(msg: "I'm protected!")

      allow(Time).to receive(:now).and_return(3600)
      get '/resource/protected', nil, @headers
      expect(response.status).to eq(401)

      post '/refresh_access_token', nil, @refresh_headers
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body.keys).to contain_exactly(:uid, :access_token, :refresh_token)
    end

    it 'can not refresh when refresh token expired' do
      allow(Time).to receive(:now).and_return(7200)
      post '/refresh_access_token', nil, @refresh_headers
      expect(response.status).to eq(403)
    end

    after do
      ApiWarden.remove_ward_by(:users)
    end
  end

  describe '#on_authenticate_failed' do
    before do
      ApiWarden.ward_by(:users, on_authenticate_failed: proc { |auth|
        render json: { custom_err_msg: 'authenticate failed' }, status: 200
      })
    end

    it 'shows custom error message' do
      get '/resource/protected'

      expect(response.status).to eq(200)
      expect(response.body).to include_json(custom_err_msg: 'authenticate failed')
    end

    after do
      ApiWarden.remove_ward_by(:users)
    end
  end

  describe '#value_for_access_token' do
    before do
      ApiWarden.ward_by(:users, value_for_access_token: proc { |access_token, uid|
        {access_token: access_token, uid: uid}.to_json
      })

      ApiWarden::RSpecHelpers.sign_in(self)
    end

    it 'renders access token value' do
      get '/resource/value_for_access_token', nil, @headers
      expect(response.body).to include_json(access_token: @auth[:access_token], uid: 1)
    end

    after do
      ApiWarden.remove_ward_by(:users)
    end
  end

  describe '#on_refresh_failed' do
    before do
      ApiWarden.ward_by(:users, on_refresh_failed: proc { |auth|
        render json: { custom_err_msg: 'refresh failed' }, status: 200
      })
    end

    it 'shows custom error message' do
      post '/refresh_access_token'
      expect(response.status).to eq(200)
      expect(response.body).to include_json(custom_err_msg: 'refresh failed')
    end

    after do
      ApiWarden.remove_ward_by(:users)
    end
  end

  describe '#value_for_refresh_token' do
    before do
      ApiWarden.ward_by(:users, value_for_refresh_token: proc { |refresh_token, uid|
        {refresh_token: refresh_token, uid: uid}.to_json
      })

      ApiWarden::RSpecHelpers.sign_in(self)
    end

    it 'renders 404 when passing no refresh token' do
      get '/resource/value_for_refresh_token', nil, @headers
      expect(response.status).to eq(404)
    end

    it 'renders refresh token value' do
      get '/resource/value_for_refresh_token', nil, @headers.merge(@refresh_headers)
      expect(response.body).to include_json(refresh_token: @auth[:refresh_token], uid: 1)
    end

    after do
      ApiWarden.remove_ward_by(:users)
    end
  end

  after do
    ApiWarden.configure do |config|
      config.redis = nil
    end
  end
end
