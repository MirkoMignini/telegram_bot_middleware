require 'sinatra'
require_relative 'telegram_bot_middleware'

use TelegramBotMiddleware do |config|
  config.token = '138381425:AAEXjzZx5U5wZmiKvFmHjdNMkXJqnkHnum4'
  #config.host = 'https://telegram-bot-middleware.herokuapp.com'
  config.host = 'http://127.0.0.1:9292'
  config.get_updates = :polling
end

get %r{/hello/?$}i do
  {
    text: "Hello #{params['from']['first_name']} #{params['from']['last_name']}!",
    reply_markup: {keyboard: [%w(A B), ['C', 'D']], resize_keyboard: true, one_time_keyboard: true, selective: false}
  }
end

get %r{/hello/([\w]+)}i do |name|
  "Hello #{name}!"
end

get %r{/image/?$}i do
  send_file 'tmp/test.png'
end

get %r{/audio/?$}i do
  send_file 'tmp/test.mp3'
end

get %r{/location/?$}i do
  {
    latitude: 38.115036, 
    longitude: 13.366640
  }
end

get '/*' do
  "Sono giapponese \u{0026C4}"
end