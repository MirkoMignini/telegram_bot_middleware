require 'sinatra'
require_relative 'telegram_bot_middleware'

use TelegramBotMiddleware do |config|
  config.token = '138381425:AAEXjzZx5U5wZmiKvFmHjdNMkXJqnkHnum4'
  #config.host = 'https://telegram-bot-middleware.herokuapp.com'
  config.host = 'http://127.0.0.1:9292'
  config.get_updates = :polling
end