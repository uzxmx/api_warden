# frozen_string_literal: true

module ApiWarden
  module Helpers
    module Accessable
      # @return [Boolean] whether or not authenticated
      def ward_by(scope)
        current_authentication_for(scope).authenticated?
      end

      # If not authenticated, an unauthorized response is rendered.
      #
      # @return [Boolean] whether or not authenticated
      def ward_by!(scope)
        scope = validate_scope(scope)
        
        authentication = current_authentication_for(scope)
        unless authentication.authenticated?
          if (block = scope.on_authenticate_failed) && block.respond_to?(:call)
            instance_exec(authentication, &block)
          else
            render json: { err_msg: 'Unauthorized' }, status: 401
          end
          false
        else
          true
        end
      end

      def current_authentication_for(scope)
        scope = validate_scope(scope)

        ivar_authentication = "@current_#{scope.name}_authentication"
        unless authentication = instance_variable_get(ivar_authentication)
          authentication = Authentication.new(scope, request)
          instance_variable_set(ivar_authentication, authentication)
        else
          authentication
        end
      end

      def generate_access_token_for(scope, id, *args)
        scope = validate_scope(scope)

        access_token = ApiWarden.friendly_token(20)

        ApiWarden.redis do |conn|
          conn.set(scope.key_for_access_token(id, access_token), 
            scope.value_for_access_token(access_token, *args), 
            ex: scope.expire_time_for_access_token
          )
        end

        access_token
      end

      private
        def validate_scope(scope)
          scope.is_a?(String) ? ApiWarden.find_scope(scope) : scope
        end          
    end
  end
end
