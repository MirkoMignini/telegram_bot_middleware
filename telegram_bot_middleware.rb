require 'rack'
require 'uri'
require 'excon'
require 'http'
require_relative 'ostruct_nested'

class TelegramBotMiddleware
  TELEGRAM_ENDPOINT = 'https://api.telegram.org/'
  
  def initialize(app, &block)    
    @app = app
    
    @config = OpenStruct.new
    yield(@config) if block_given?
    
    #setup connection to telegram
    @connection = Excon.new(TELEGRAM_ENDPOINT, persistent: true)

    if @config.webhook.nil?
      @config.host = "#{@config.host}/" unless @config.host.end_with?('/')
      @config.webhook = "#{@config.host}#{@config.token}"
    end
    
    case @config.get_updates
      
      when :polling
        send_to_bot('setWebhook', {url: ''})
        
        Thread.new do
          @offset = 0
          loop do
            response = send_to_bot('getUpdates', {offset: @offset})
            update = OpenStruct.from_json(response.data[:body])
            
            if update.result.any?
              @offset = update.result.last.update_id + 1 
              update.result.each do |data|
                HTTP.post @config.webhook, json: data.to_h_nested
              end
            end
              
          end
        end
      
      when :webhook
        send_to_bot('setWebhook', {url: @config.webhook})
      
      else
        raise ArgumentError.new('Config error: get_updates must be :webhook or :polling.')
    end
  end

  def call(env)
    #retrieve the request object
    req = Rack::Request.new(env)
    
    #if the request is a post to bot webhhok
    if req.post? and req.path == "/#{@config.token}"
      
      #build an openstruct based on post params
      req.body.rewind  # in case someone already read it
      params = OpenStruct.from_json(req.body.read)
      
      #build path based on message
      # - get only message part of post params
      # - remove empty chars from beginning or end (strip)
      # - replace spaces with /
      # - encode as uri
      path = URI.escape(params.message.text.strip.gsub(/\s+/, '/'))
      # - add first / if not present
      path = "/#{path}" unless path.start_with?('/')
      
      #build the querystring using message but nested
      query_string = Rack::Utils.build_nested_query(params.message.to_h_nested)
      
      #transform the POST in GET
      env['PATH_INFO'] = path
      env['QUERY_STRING'] = query_string
      env['REQUEST_METHOD'] = 'GET'
      env['REQUEST_URI'] = "https://#{req.host}#{path}"
      #TODO
      #use update(hash) { |name, old_value, new_value| }
      
      #call the rack stack
      status, headers, body = @app.call(env)
      
      if status == 200
        case headers['Content-Type'].split(';').first
          when 'text/html', 'application/json'          
            
            query = Hash.new
            if body.is_a? Hash
              
              query = body.clone
              query[:chat_id] = params.message.chat.id unless query.include?(:chat_id)
              query[:reply_markup] = query[:reply_markup].to_json if query.include?(:reply_markup)
              
              body = Array.new(1) { query[:text] }
            else
              query = {chat_id: params.message.chat.id, text: body.first}
            end
            puts query.inspect
            send_to_bot('sendMessage', query)
        end
      end
      
      #return result
      [status, headers, body]
    else
      #normal rack flow - not a bot call
      @app.call(env)
    end
  end
  
  def send_to_bot(path, query)
    @connection.post(path: "/bot#{@config.token}/#{path}", query: query)
  end
end
