# frozen_string_literal: true

require 'connection_pool'
require 'redis'

module ApiWarden
  class RedisConnection
    class << self

      def create(options = {})
        options[:url] ||= determine_redis_provider
        size = options[:size] || 5
        pool_timeout = options[:pool_timeout] || 1
        ConnectionPool.new(:timeout => pool_timeout, :size => size) do
          build_client(options)
        end
      end

      private

      def build_client(options)
        namespace = options[:namespace]

        client = Redis.new client_opts(options)
        if namespace
          begin
            require 'redis/namespace'
            Redis::Namespace.new(namespace, :redis => client)
          rescue LoadError
            puts "Your Redis configuration uses the namespace '#{namespace}' but the redis-namespace gem is not included in the Gemfile." \
                                 "Add the gem to your Gemfile to continue using a namespace. Otherwise, remove the namespace parameter."
            exit(-127)
          end
        else
          client
        end
      end

      def client_opts(options)
        opts = options.dup
        if opts[:namespace]
          opts.delete(:namespace)
        end

        if opts[:network_timeout]
          opts[:timeout] = opts[:network_timeout]
          opts.delete(:network_timeout)
        end

        opts[:driver] ||= 'ruby'

        # redis-rb will silently retry an operation.
        # This can lead to duplicate jobs if Sidekiq::Client's LPUSH
        # is performed twice but I believe this is much, much rarer
        # than the reconnect silently fixing a problem; we keep it
        # on by default.
        opts[:reconnect_attempts] ||= 1

        opts
      end

      def determine_redis_provider
        ENV[ENV['REDIS_PROVIDER'] || 'REDIS_URL']
      end

    end
  end
end
