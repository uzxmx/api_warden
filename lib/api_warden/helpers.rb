# frozen_string_literal: true

module ApiWarden
  module Helpers
    autoload :Accessable, 'api_warden/helpers/accessable'
    autoload :Refreshable, 'api_warden/helpers/refreshable'

    def self.define_helpers(scope)
      name = scope.name

      class_eval <<-METHODS, __FILE__, __LINE__ + 1
        def ward_by_#{name}
          ward_by("#{name}")
        end

        def ward_by_#{name}!
          ward_by!("#{name}")
        end

        def current_#{name}_authentication
          current_authentication_for("#{name}")
        end

        def current_#{name}_id
          current_#{name}_authentication.id
        end

        def current_#{name}_value_for_access_token
          current_#{name}_authentication.value_for_access_token
        end        

        def #{name}_signed_in?
          current_#{name}_authentication.authenticated?
        end

        def generate_access_token_for_#{name}(id, *args)
          generate_access_token_for("#{name}", id, *args)
        end
      METHODS

      if scope.load_owner.respond_to?(:call)
        class_eval <<-METHODS, __FILE__, __LINE__ + 1
          def current_#{name}
            unless @current_#{name}
              scope = ApiWarden.find_scope("#{name}")
              @current_#{name} = scope.load_owner.call(
                current_#{name}_id, 
                current_#{name}_value_for_access_token, 
                current_#{name}_authentication
              )
            end
            @current_#{name}
          end
        METHODS
      end

      unless scope.disable_refresh_token?
        class_eval <<-METHODS, __FILE__, __LINE__ + 1
          def generate_refresh_token_for_#{name}(id, *args)
            generate_refresh_token_for("#{name}", id, *args)
          end

          def generate_tokens_for_#{name}(id, *args)
            [generate_access_token_for_#{name}(id, *args), generate_refresh_token_for_#{name}(id, *args)]
          end

          def validate_refresh_token_for_#{name}!
            validate_refresh_token_for!("#{name}")
          end          
        METHODS
      end

      ActiveSupport.on_load(:action_controller) do
        include ApiWarden::Helpers, Accessable
        include Refreshable unless scope.disable_refresh_token?

        if respond_to?(:helper_method)
          helper_method "current_#{name}_authentication", "current_#{name}_id", "current_#{name}_value_for_access_token", "#{name}_signed_in?"

          if scope.load_owner.respond_to?(:call)
            helper_method "current_#{name}"
          end
        end
      end
    end

    def self.remove_helpers(scope)
      name = scope.name

      ["ward_by_#{name}",
       "ward_by_#{name}!",
       "current_#{name}_authentication",
       "current_#{name}_id",
       "current_#{name}_value_for_access_token",
       "#{name}_signed_in?",
       "generate_access_token_for_#{name}"].each { |s| undef_method s }

      unless scope.disable_refresh_token?
        ["generate_refresh_token_for_#{name}",
         "generate_tokens_for_#{name}",
         "validate_refresh_token_for_#{name}!"].each { |s| undef_method s }
      end
    end
  end
end
