# frozen_string_literal: true

module ApiWarden
  class Authentication
    class HeaderParams < Params

      def headers
        request.headers
      end

      def retrieve_id
        @id ||= headers["X-#{scope.name.camelize}-Id"]
      end

      def retrieve_access_token
        @access_token ||= headers["X-#{scope.name.camelize}-Access-Token"]
      end

      def retrieve_refresh_token
        @refresh_token ||= headers["X-#{scope.name.camelize}-Refresh-Token"]
      end
    end
  end
end