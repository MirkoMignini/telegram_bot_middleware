require_relative '../../lib/telegram_bot_middleware'

use TelegramBotMiddleware do |config|
  config.token = '138381425:AAEXjzZx5U5wZmiKvFmHjdNMkXJqnkHnum4'
  config.host = 'http://127.0.0.1:9292'
  config.get_updates = :polling
end

run Proc.new { |env| [200, {'Content-Type' => 'text/html'}, ['Hello world!']] }