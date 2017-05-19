require_relative 'example_init'

get %r{/telegram/hello$}i do
  {
    text: "Hello #{params['from']['first_name']} #{params['from']['last_name']}!",
    reply_markup: {keyboard: [%w(A B), ['C', 'D']], resize_keyboard: true, one_time_keyboard: true, selective: false}
  }
end

get %r{/telegram/greets/(.*)}i do |name|
  "Hello #{name}!"
end

get %r{/telegram/image/?$}i do
  #send_file 'tmp/test.png'
  {
    photo: '../../tmp/test.png',
    caption: 'caption'
  }
end

get %r{/telegram/audio/?$}i do
  send_file 'tmp/test.mp3'
end

get %r{/telegram/video/?$}i do
  send_file 'tmp/test.mp4'
end

get '/telegram/location' do
  {
    latitude: params['location']['latitude'],
    longitude: params['location']['longitude'],
  }
end

get %r{/telegram/location/?$}i do
  {
    latitude: 38.115036, 
    longitude: 13.366640
  }
end

get %r{/telegram/test/?$}i do
  {
    multiple: 
    [
      {
        photo: '../../tmp/test.png',
        caption: 'caption'
      },
      {
        text: 'ciao'
      },
      {
        latitude: 38.115036, 
        longitude: 13.366640
      }
    ]
  }
end

get '/telegram/inline_query' do
  {
    results:
    [
      {
        type: 'article',
        id: 'identifier',
        title: 'Test',
        message_text: 'Description'
      }
    ]
  }
end

get '*' do
  "Sono giapponese \u{0FE4E5}"
end