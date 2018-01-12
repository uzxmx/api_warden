# frozen_string_literal: true

module ApiWarden
  module Helpers
    module Refreshable
      def generate_refresh_token_for(scope, id, *args)
        scope = validate_scope(scope)

        refresh_token = ApiWarden.friendly_token(30)

        ApiWarden.redis do |conn|
          conn.set(scope.key_for_refresh_token(id, refresh_token), 
            scope.value_for_refresh_token(refresh_token, *args), 
            ex: scope.expire_time_for_refresh_token
          )
        end

        refresh_token
      end

      # If not refreshable, a forbidden response is rendered.
      #
      # @return [Boolean] whether or not refreshable
      def validate_refresh_token_for!(scope)
        scope = validate_scope(scope)

        authentication = current_authentication_for(scope)
        unless authentication.refreshable?
          if (block = scope.on_refresh_failed) && block.respond_to?(:call)
            instance_exec(authentication, &block)
          else
            render json: { err_msg: 'Forbidden' }, status: 403
          end
          false
        else
          true
        end
      end

      private
        def validate_scope(scope)
          scope.is_a?(String) ? ApiWarden.find_scope(scope) : scope
        end      
    end
  end
end
