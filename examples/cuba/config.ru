require 'cuba'
require_relative '../../lib/telegram_bot_middleware'

Cuba.use TelegramBotMiddleware do |config|
  config.token = '138381425:AAEXjzZx5U5wZmiKvFmHjdNMkXJqnkHnum4'
  config.host = 'http://127.0.0.1:9292'
  config.get_updates = :polling
end

Cuba.define do
  on get do
    on /.*/ do
      res.write 'Hello world!'
    end
  end
end

warmup do |app|
  client = Rack::MockRequest.new(app)
  client.get('/')
end

run Cuba