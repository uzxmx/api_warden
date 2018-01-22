# frozen_string_literal: true

module ApiWarden
  class Scope
    EXPIRE_TIME_FOR_ACCESS_TOKEN = 7.days.seconds
    EXPIRE_TIME_FOR_REFRESH_TOKEN = 14.days.seconds

    attr_reader :name, :options

    # ==== Options
    #
    #  * params_class: [ApiWarden::Authentication::Params]
    #      the class from which to retrieve authentication related params. Default is 
    #      ApiWarden::Authentication::HeaderParams.
    #
    #  * load_owner: [Proc]
    #      the block to be called to load the owner for the scope, so that you can call current_#{scope}
    #      to access the owner. Id, value for the access token and the authentication will be passed as arguments.
    #
    #        ApiWarden.ward_by(:users, load_owner: proc { |id, value, auth| User.find(id) })
    #
    #  * disable_refresh_token: [Boolean]
    #      whether or not to disable using refresh token to refresh access token. Default is false.
    #
    #  * expire_time_for_access_token: [Fixnum]
    #      the expire time for access token in seconds. Default is EXPIRE_TIME_FOR_ACCESS_TOKEN.
    #
    #  * value_for_access_token: [Proc]
    #      the block will be called to obtain the value for the access token key. The block will be
    #      passed with access_token, and other args you specified when calling generate_tokens_for.
    #      By default the access token will be used as the value.
    #
    #  * on_authenticate_failed: [Proc]
    #      the block to be called when authentication failed. An authentication will be passed as an argument.
    #
    #  * on_authenticate_success: [Proc]
    #      the block to be called when authentication succeeds. An authentication will be passed as an argument.
    #
    #  * expire_time_for_refresh_token: [Fixnum]
    #      the expire time for refresh token in seconds, default is EXPIRE_TIME_FOR_REFRESH_TOKEN.
    #
    #  * value_for_refresh_token: [Proc]
    #      the block will be called to obtain the value for the refresh token key. The block will be
    #      passed with refresh_token, and other args you specified when calling generate_tokens_for.
    #      By default the refresh token will be used as the value.
    #
    #  * on_refresh_failed: [Proc]
    #      the block to be called when refreshing failed. An authentication will be passed as an argument.
    def initialize(name, options = {})
      @name = name

      options[:params_class] ||= ApiWarden::Authentication::HeaderParams
      options[:disable_refresh_token] ||= false
      options[:expire_time_for_access_token] ||= EXPIRE_TIME_FOR_ACCESS_TOKEN
      options[:expire_time_for_refresh_token] ||= EXPIRE_TIME_FOR_REFRESH_TOKEN

      @options = options
    end

    def key_for_access_token(id, access_token)
      "#{@name}_#{id}_access_token_#{access_token}"
    end

    def value_for_access_token(access_token, *args)
      if options[:value_for_access_token].respond_to?(:call)
        options[:value_for_access_token].call(access_token, *args)
      else
        access_token
      end
    end

    def key_for_refresh_token(id, refresh_token)
      "#{@name}_#{id}_refresh_token_#{refresh_token}"
    end

    def value_for_refresh_token(refresh_token, *args)
      if options[:value_for_refresh_token].respond_to?(:call)
        options[:value_for_refresh_token].call(refresh_token, *args)
      else
        refresh_token
      end
    end

    private
      def method_missing(method_name, *args)
        key = (method_name[-1] == "?" ? method_name[0..-2] : method_name).to_sym
        options[key]
      end
  end
end