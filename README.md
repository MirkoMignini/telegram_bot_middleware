# TelegramBotMiddleware

Rack middleware to communicate with a telegram bot.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'telegram_bot_middleware'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install telegram_bot_middleware
    
Add the middleware in config.ru or in other files base on the framework you are using:

```ruby
require 'telegram_bot_middleware'

use TelegramBotMiddleware do |config|
  config.token = '<TELEGRAM_TOKEN>'
  config.host = '<HOST>'
  config.get_updates = :polling or :webhook
end
```

* To obtain a token follow the instructions in [telegram bot api](https://core.telegram.org/bots#botfather).
* The host is the address where the script is running, for example during development could be http://127.0.0.1:9292.
* The get_updates params specify how to get incoming messages from telegram, can be :polling or :webhook, look at the [telegram bot api](https://core.telegram.org/bots/api#getupdates) for details.

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MirkoMignini/telegram_bot_middleware. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

