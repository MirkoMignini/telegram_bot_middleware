require 'sinatra'
require_relative 'telegram_bot_middleware'

use TelegramBotMiddleware do |config|
  config.token = '138381425:AAEXjzZx5U5wZmiKvFmHjdNMkXJqnkHnum4'
  config.host = 'http://127.0.0.1:9292'
  config.get_updates = :polling
end

calc_string = ''

get %r{calc/?$}i do
  calc_string = ''
  {
    text: "Let's calc!",
    reply_markup: {keyboard: [%w(7 8 9 *), %w(4 5 6 /), %w(1 2 3 -), %w(0 . = +)], resize_keyboard: true, one_time_keyboard: false, selective: false}
  }
end

get %r{(0|1|2|3|4|5|6|7|8|9|\*|\/|-|\.|\+)$} do |cmd|
  calc_string += cmd
end

get '/=' do
  {
    text: eval(calc_string).to_s,
    reply_markup: {hide_keyboard: true}
  }
end