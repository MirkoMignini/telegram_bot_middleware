require_relative 'example_init'

use Rack::Session::Cookie, :key => 'rack.session',
                           :domain => 'foo.com',
                           :path => '/',
                           :expire_after => 2592000, # In seconds
                           :secret => 'some_secret'

get %r{calc/?$}i do
  session[:result] = ''
  {
    text: "Let's calc!",
    reply_markup: {keyboard: [%w(7 8 9 *), %w(4 5 6 /), %w(1 2 3 -), %w(0 . = +)], resize_keyboard: true, one_time_keyboard: false, selective: false}
  }
end

get %r{(0|1|2|3|4|5|6|7|8|9|\*|\/|-|\.|\+)$} do |cmd|
  session[:result] += cmd
end

get '/=' do
  {
    text: eval(session[:result]).to_s,
    reply_markup: {hide_keyboard: true}
  }
end