require 'rails_helper'

RSpec.describe 'Authentication', :type => :request do
  before do
    Redis.new.flushall

    ApiWarden.configure do |config|
      config.redis = ConnectionPool.new(:timeout => 1, :size => 1) { Redis.new }
    end
    ApiWarden.ward_by(:users)

    allow(Time).to receive(:now).and_return(0)
  end

  context 'without access token' do
    it 'succeeds when accessing to unprotected resource' do
      get '/resource/unprotected'

      expect(response.body).to include_json(msg: "I'm unprotected!")
    end

    it 'renders 401 response status when accessing to protected resource' do
      get '/resource/protected'

      expect(response.status).to eq(401)
      expect(response.body).to include_json(err_msg: 'Unauthorized')
    end
  end

  it 'can sign in' do
    post '/sign_in'

    body = JSON.parse(response.body, symbolize_names: true)
    expect(body.keys).to contain_exactly(:uid, :access_token, :refresh_token)
  end

  context 'with access token' do
    before do
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

    it 'has access to unprotected resource' do
      get '/resource/unprotected', headers: @headers

      expect(response.body).to include_json(msg: "I'm unprotected!")
    end

    it 'has access to protected resource' do
      get '/resource/protected', headers: @headers

      expect(response.body).to include_json(msg: "I'm protected!")
    end

    it 'can sign out' do
      delete '/sign_out', headers: @headers
      expect(response.body).to include_json(succ: true)

      get '/resource/protected', headers: @headers
      expect(response.status).to eq(401)
    end

    it 'does not have access to protected resource when using wrong id' do
      @headers[:'X-User-Id'] = 2
      get '/resource/protected', headers: @headers

      expect(response.status).to eq(401)
    end

    it 'does not have access to protected resource when using wrong token' do
      @headers[:'X-User-Access-Token'] += 'suffix'
      get '/resource/protected', headers: @headers

      expect(response.status).to eq(401)
    end

    context 'when access token expired' do
      before do
        allow(Time).to receive(:now).and_return(ApiWarden::Scope::EXPIRE_TIME_FOR_ACCESS_TOKEN)
      end

      it 'does not have access to protected resource' do
        get '/resource/protected', headers: @headers

        expect(response.status).to eq(401)
      end

      it 'can not refresh access token without uid or refresh token' do
        post '/refresh_access_token'
        expect(response.status).to eq(403)

        post '/refresh_access_token', headers: @refresh_headers.dup.tap { |h| h.delete(:'X-User-Id') }
        expect(response.status).to eq(403)

        post '/refresh_access_token', headers: @refresh_headers.dup.tap { |h| h.delete(:'X-User-Refresh-Token') }
        expect(response.status).to eq(403)
      end

      it 'can not refresh access token when using an expired refresh token' do
        allow(Time).to receive(:now).and_return(ApiWarden::Scope::EXPIRE_TIME_FOR_REFRESH_TOKEN)

        post '/refresh_access_token', headers: @refresh_headers

        expect(response.status).to eq(403)
      end

      it 'can refresh access token' do
        post '/refresh_access_token', headers: @refresh_headers

        body = JSON.parse(response.body, symbolize_names: true)
        expect(body.keys).to contain_exactly(:uid, :access_token, :refresh_token)
      end

      context "after refreshing access token" do
        before do
          post '/refresh_access_token', headers: @refresh_headers
          @auth = JSON.parse(response.body, symbolize_names: true)
          @headers = {
            'X-User-Id': @auth[:uid],
            'X-User-Access-Token': @auth[:access_token]
          }
        end

        it 'fails if using old refresh token' do
          post '/refresh_access_token', headers: @refresh_headers

          expect(response.status).to eq(403)
        end

        it 'has access to protected resource' do
          get '/resource/protected', headers: @headers

          expect(response.body).to include_json(msg: "I'm protected!")
        end
      end
    end
  end

  after do
    ApiWarden.configure do |config|
      config.redis = nil
    end

    ApiWarden.remove_ward_by(:users)
  end
end
