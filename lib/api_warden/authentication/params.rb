# frozen_string_literal: true

module ApiWarden
  class Authentication
    class Params
      attr_reader :authentication

      def initialize(authentication)
        @authentication = authentication
      end

      def scope
        authentication.scope
      end

      def request
        authentication.request
      end

      def retrieve_id
        raise NotImplementedError
      end

      def retrieve_access_token
        raise NotImplementedError
      end

      def retrieve_refresh_token
        raise NotImplementedError
      end
    end
  end
end