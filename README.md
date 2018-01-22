# ApiWarden

This is a gem that you can use to protect your API in rails. By default it uses access token to authenticate the requests, and uses refresh token to get new access token when access token expires.

## Examples

https://github.com/UzxMx/api_warden_examples

## Usage

* Add the gem to your application's Gemfile. And execute `bundle install`
```
gem 'api_warden'
```

* Create a file config/initializers/api_warden.rb. And add the below codes.
```
ApiWarden.configure do |config|
  config.redis = {
    host: 'localhost',
    port: 8877,
    size: 8
  }
end

ApiWarden.ward_by('users')
```

* Create app/controllers/base_controller.rb. And add the below codes.
```
class BaseController < ActionController::Base
  before_action :ward_by_user!
end
```

* Create app/controllers/users_controller.rb. And add the below codes.
```
class UsersController < BaseController
  skip_before_action :ward_by_user!, only: [:sign_in]

  def sign_in
    # If the request is allowed to sign in a user, then continue to execute, otherwise return directly.
    access_token, refresh_token = generate_tokens_for_user(user_id)
    render json: {
      user_id: user_id,
      access_token: access_token,
      refresh_token: refresh_token
    }
  end
end
```

* In client side, you need to add below http headers to access the server protected resources.
```
X-User-Id: <the user id rendered in sign in api>
X-User-Access-Token: <the access token rendered in sign in api>
```

* If the access token expires, you need to use the refresh token to get a new pair of access and refresh token. Modify the users_controller.rb.
```
class UsersController < BaseController
  skip_before_action :ward_by_user!, only: [:sign_in, :refresh_token]

  def sign_in
    # If the request is allowed to sign in a user, then continue to execute, otherwise return directly.
    access_token, refresh_token = generate_tokens_for_user(user_id)
    render json: {
      user_id: user_id,
      access_token: access_token,
      refresh_token: refresh_token
    }
  end

  def refresh_token
    if validate_refresh_token_for_user!
      user_id = current_user_authentication.id
      access_token, refresh_token = generate_tokens_for_user(user_id)
      render json: {
        user_id: user_id,
        access_token: access_token,
        refresh_token: refresh_token
      }      
    end    
  end
end
```

* In client side, when requesting the refresh token api, you need to add below http headers.
```
X-User-Id: <the user id rendered in sign in api>
X-User-Refresh-Token: <the refresh token rendered in sign in api>
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/UzxMx/api_warden. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ApiWarden project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/UzxMx/api_warden/blob/master/CODE_OF_CONDUCT.md).
