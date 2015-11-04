require './example'

$stdout.sync = true

warmup do |app|
  client = Rack::MockRequest.new(app)
  client.get('/')
end

run Sinatra::Application