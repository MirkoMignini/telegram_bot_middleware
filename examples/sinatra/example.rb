require_relative 'example_init'

get %r{/hello$}i do
  {
    text: "Hello #{params['from']['first_name']} #{params['from']['last_name']}!",
    reply_markup: {keyboard: [%w(A B), ['C', 'D']], resize_keyboard: true, one_time_keyboard: true, selective: false}
  }
end

get %r{/hello/(.*)}i do |name|
  "Hello #{name}!"
end

get %r{/image/?$}i do
  send_file 'tmp/test.png'
end

get %r{/audio/?$}i do
  send_file 'tmp/test.mp3'
end

get %r{/video/?$}i do
  send_file 'tmp/test.mp4'
end

get %r{/location/?$}i do
  {
    latitude: 38.115036, 
    longitude: 13.366640
  }
end

get %r{/caption/?$}i do
  {
    photo: File.new('tmp/test.png'),
    caption: 'caption'
  }
end

get '*' do
  "Sono giapponese \u{0FE4E5}"
end