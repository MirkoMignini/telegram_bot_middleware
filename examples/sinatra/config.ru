# require './example'
require './calc'
# require './chuck_norris'

$stdout.sync = true

warmup do |app|
  client = Rack::MockRequest.new(app)
  client.get('/')
end

run Sinatra::Application
