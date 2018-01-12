# frozen_string_literal: true

require 'rails'
require 'connection_pool'

module ApiWarden
  autoload :Authentication, 'api_warden/authentication'
  autoload :Helpers, 'api_warden/helpers'
  autoload :RedisConnection, 'api_warden/redis_connection'
  autoload :Scope, 'api_warden/scope'
  autoload :Version, 'api_warden/version'

  SCOPES = Hash.new

  # Configuration for ApiWarden, use like:
  #
  #   ApiWarden.configure do |config|
  #     config.redis = { :namespace => 'myapp', :size => 1, :url => 'redis://myhost:8877/0' }
  #   end
  def self.configure
    yield self
  end

  # Add a scope to ward. Some methods related with the scope will be generated and mixed into
  # ActionController::Base.
  #
  # ==== Examples
  #
  #   ApiWarden.ward_by('users')
  #   ApiWarden.ward_by('users', expire_time_for_access_token: 2.days.seconds)
  #   ApiWarden.ward_by('users', value_for_access_token: proc { |access_token, *args| ... })
  #
  # @param scope [String]
  # @param options [Hash] see Scope#initialize
  def self.ward_by(scope, options = {})
    name = validate_scope_name(scope)
    raise "Scope #{name} already defined" if find_scope(name)

    scope = Scope.new(name, options)
    SCOPES[name] = scope
    Helpers.define_helpers(scope)
  end

  # @return [Boolean] true if removed successfully, false otherwise.
  def self.remove_ward_by(scope)
    if scope = find_scope(scope)
      Helpers.remove_helpers(scope)
      SCOPES.delete(scope.name)
      true
    else
      false
    end
  end

  def self.find_scope(name)
    name = validate_scope_name(name)
    SCOPES[name]
  end

  def self.redis
    raise ArgumentError, 'requires a block' unless block_given?
    redis_pool.with do |conn|
      retryable = true
      begin
        yield conn
      rescue Redis::CommandError => ex
        # Failover can cause the server to become a slave, need
        # to disconnect and reopen the socket to get back to the master.
        (conn.disconnect!; retryable = false; retry) if retryable && ex.message =~ /READONLY/
        raise
      end
    end
  end

  def self.redis_pool
    @redis ||= RedisConnection.create
  end

  def self.redis=(hash)
    @redis = if hash.is_a?(ConnectionPool)
      hash
    elsif hash
      RedisConnection.create(hash)
    end
  end

  # Generate a friendly string randomly to be used as token.
  # By default, length is 20 characters.
  def self.friendly_token(length = 20)
    # To calculate real characters, we must perform this operation.
    # See SecureRandom.urlsafe_base64
    rlength = (length * 3) / 4
    SecureRandom.urlsafe_base64(rlength).tr('lIO0', 'sxyz')
  end

  private
    def self.validate_scope_name(scope)
      scope.to_s.singularize.downcase
    end 
end
