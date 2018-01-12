# frozen_string_literal: true

module ApiWarden
  class Authentication
    autoload :Params, 'api_warden/authentication/params'
    autoload :HeaderParams, 'api_warden/authentication/header_params'

    attr_reader :scope, :request, :params

    def initialize(scope, request)
      @scope = scope
      @request = request
      @params = scope.params_class.new(self)
    end

    def authenticated?
      ensure_authenticated
      @authenticated
    end

    def refreshable?
      ensure_refreshable
      @refreshable
    end

    def id
      ensure_authenticated_or_refreshable
      @id
    end

    def value_for_access_token
      ensure_authenticated
      @value_for_access_token
    end

    def value_for_refresh_token
      ensure_refreshable
      @value_for_refresh_token
    end

    # @return self
    def authenticate
      authenticate!
    rescue AuthenticationError => e
      self
    end

    # This method will only authenticate once, and cache the result.
    #
    # @return self
    def authenticate!
      return unless @authenticated.nil?

      id, access_token = @params.retrieve_id, @params.retrieve_access_token
      key = @scope.key_for_access_token(id, access_token)

      if access_token && !access_token.empty?
        ApiWarden.redis { |conn| @value_for_access_token = conn.get(key) }
      end

      unless @value_for_access_token
        @authenticated = false
        raise AuthenticationError        
      end

      @authenticated = true
      @id = id
      @access_token = access_token
      self
    end

    def validate_refresh_token
      validate_refresh_token!
    rescue AuthenticationError => e
    end

    def validate_refresh_token!
      return unless @refreshable.nil?

      id, refresh_token = @params.retrieve_id, @params.retrieve_refresh_token
      key = @scope.key_for_refresh_token(id, refresh_token)

      if refresh_token && !refresh_token.empty?
        ApiWarden.redis do |conn|
          @value_for_refresh_token = conn.get(key)
          conn.del(key)
        end
      end

      unless @value_for_refresh_token
        @refreshable = false
        raise AuthenticationError
      end

      @refreshable = true
      @id = id
      self      
    end

    # TODO remove refresh token as well
    def sign_out
      key = @scope.key_for_access_token(@id, @access_token)

      ApiWarden.redis { |conn| conn.del(key) }
    end

    private
      def ensure_authenticated
        return unless @authenticated.nil?
        authenticate
      end

      def ensure_refreshable
        return unless @refreshable.nil?
        validate_refresh_token
      end

      def ensure_authenticated_or_refreshable
        ensure_authenticated
        ensure_refreshable unless @authenticated
      end

    class AuthenticationError < Exception
    end
  end
end
