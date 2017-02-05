$LOAD_PATH.unshift File.expand_path('../../../lib', __FILE__)
require 'sinatra'
require 'telegram_bot_middleware'

configure :development do
  set :logging, Logger::DEBUG
end

use TelegramBotMiddleware do |config|
  config.token = '138381425:AAEXjzZx5U5wZmiKvFmHjdNMkXJqnkHnum4'
  #config.host = 'https://telegram-bot-middleware.herokuapp.com'
  config.host = 'http://127.0.0.1:9292'
  config.get_updates = :polling
  config.prefix='telegram'
end
