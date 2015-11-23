[![Build Status](https://travis-ci.org/MirkoMignini/telegram_bot_middleware.svg)](https://travis-ci.org/MirkoMignini/telegram_bot_middleware)
[![Coverage Status](https://coveralls.io/repos/MirkoMignini/telegram_bot_middleware/badge.svg?branch=master&service=github)](https://coveralls.io/github/MirkoMignini/telegram_bot_middleware?branch=master)

# Telegram Bot Middleware

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
    
Add the middleware in config.ru or in other files based on the framework you are using:

```ruby
require 'telegram_bot_middleware'

use TelegramBotMiddleware do |config|
  config.token = '<TELEGRAM_TOKEN>'
  config.host = '<HOST>'
end
```

### Config options:
* token (required): to obtain the token follow the instructions in [telegram bot api](https://core.telegram.org/bots#botfather).
* host (required): is the address where the script is running, for example during development could be http://127.0.0.1:9292.
* get_updates (optional, default is :polling) params specify how to get incoming messages from telegram, can be :polling or :webhook, look at the [telegram bot api](https://core.telegram.org/bots/api#getupdates) for details.
* connection_pool_size (optional, default is 2):
* connection_keep_alive (optional, default is 30):
* connection_force_retry (optional, default is true):

## Usage

After the middleware is added to your preferred framework and configured as specified in installation instructions, you are ready to receive and send message to your telegram bot.
Every message from the chat where the bot is added is received from your application as a GET request.

### Text messages

In case of a text message, the text will be escaped as URI and the first work will be the command, let's see how every message is parsed (message -> result):
* '/test' -> '/test'
* 'test' -> '/test'
* 'test test2' -> '/test/test2'
* 'test test2 test3' -> '/test/test2%20test3'

You can use your preferred framework router to handle the GET requests, for example:
```ruby
get %r{/greets/(.*)}i do |name| 
  "Hello #{name}!"
end
```
If the chat input is for example 'greets Mike' the bot output will be 'Hello Mike!'

Every message received from the chat contains parameters as specified in [bot api](https://core.telegram.org/bots/api#message) in the form of query string parameters, let's see an example:
```ruby    
get %r{/hello$}i do 
  "Hello #{params['from']['first_name']} #{params['from']['last_name']}!"
end
```

### Other types of messages
The middleware supports also every other kind of message from bot, here is the list:
* audio 
* document 
* photo 
* sticker 
* video 
* voice 
* contact 
* location 
* new_chat_participant 
* left_chat_participant 
* new_chat_title 
* new_chat_photo 
* delete_chat_photo 
* group_chat_created

Every message of this kind is routed as a GET request, the command is the message itself and the message parameters are in querystring, for example:
```ruby
get '/location' do
  "Your coordinates are: #{params['location']['latitude']} #{params['location']['longitude']}"
end
```

### Return types
Depending on the return types of your functions differents telegram methods are used to send bot messages to chat.

#### Plain text
When the function return a string is sent as-is using the [sendMessage Telegram function](https://core.telegram.org/bots/api#sendmessage).

#### JSON return types
When the function return a json a different telegram function is called depending the json content, for example:
```ruby
{ text: 'Hello', reply_markup: {keyboard: [%w(A B), %w(C D)]} }
```
In this case the [sendMessage Telegram function](https://core.telegram.org/bots/api#sendmessage) is called but with additional parameter as specified (reply_markup in this case). You can use every telegram functions parameter.

To return a location the json has to contains latitude and longitude, obviously is possible to use every optional parameters as specified in [sendLocation Telegram function](https://core.telegram.org/bots/api#sendlocation)
```ruby
{ latitude: 38.115036, longitude: 13.366640 }
```

To return a photo with a caption it's necessary to specify the picture path:
```ruby
{ photo: 'tmp/test.png', caption: 'Awesome picture!' }
```
The same to return other types according to [Telegram documentation](https://core.telegram.org/bots/api#available-methods)

#### Documents, audio, video, images...
If the function returns a file, as showing in the following sinatra snippet:
```ruby
send_file 'tmp/test.png'
```
According to the file MIME type the appropriate telegram function is called, [sendPhoto](https://core.telegram.org/bots/api#sendphoto) in this example.

#### Multiple return messages
Sometimes can be useful to return more than one message, do this is very simple, it's enough to return an array of single messages json encapsulated with the multiple keyword, example:
```ruby
{
  multiple: 
  [
    {
      photo: 'tmp/test.png',
      caption: 'image caption'
    },
    {
      text: 'Hello'
    },
    {
      latitude: 38.115036, 
      longitude: 13.366640
    }
  ]
}
```
In this case the bot will send an image, a message and a location.

### Session and cookies
The middleware supports the standard sessions variables, that are stored as a cookie and the values are valid for the given chat, see the [calculator sample](https://github.com/MirkoMignini/telegram_bot_middleware/blob/master/examples/sinatra/calc.rb).

## Examples

To run an example call:
```shell
    $ rackup
```
In the desired example folder

### Basic examples in various frameworks
There are various ready to go basic examples in the following frameworks:
* [Sinatra](https://github.com/MirkoMignini/telegram_bot_middleware/tree/master/examples/sinatra)
* [Cuba](https://github.com/MirkoMignini/telegram_bot_middleware/tree/master/examples/cuba)
* [Roda](https://github.com/MirkoMignini/telegram_bot_middleware/tree/master/examples/roda)
* [Rack](https://github.com/MirkoMignini/telegram_bot_middleware/tree/master/examples/rack)

### Little bot examples:
* [Calculator (sinatra)](https://github.com/MirkoMignini/telegram_bot_middleware/blob/master/examples/sinatra/calc.rb)
* [Random joke from Chuck Norris database (sinatra)](https://github.com/MirkoMignini/telegram_bot_middleware/blob/master/examples/sinatra/chuck_norris.rb)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MirkoMignini/telegram_bot_middleware. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

