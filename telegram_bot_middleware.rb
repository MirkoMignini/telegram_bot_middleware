require 'ostruct'
require_relative 'ostruct_nested'
require 'uri'
require 'cgi'
require 'json'
require 'excon'
require 'rack'

class TelegramBotMiddleware
  TELEGRAM_ENDPOINT = 'https://api.telegram.org/'
  
  def initialize(app, &block)
    @app = app
    
    @config = OpenStruct.new
    yield(@config) if block_given?
    
    #setup connection to telegram
    @connection = Excon.new(TELEGRAM_ENDPOINT, persistent: true)
    
    #setup webhook
    if @config.webhook.nil?
      @config.host = "#{@config.host}/" unless @config.host.end_with?('/')
      @config.webhook = "#{@config.host}#{@config.token}"
    end
    send_to_bot('setWebhook', {url: @config.webhook})
  end

  def call(env)
    #retrieve the request object
    req = Rack::Request.new(env)
    
    #if the request is a post to bot webhhok
    if req.post? and req.path == "/#{@config.token}"
      
      #build an openstruct based on post params
      params = JSON.parse(req.body.read, object_class: OpenStruct)
      
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
      
      #call the rack stack
      status, headers, body = @app.call(env)
      
      if status == 200
        case headers['Content-Type'].split(';').first
          when 'text/html', 'application/json'          
            
            query = Hash.new
            if body.is_a? Hash
              
              query = body.clone
              query[:chat_id] = params.message.chat.id unless query.include?(:chat_id)
              
              body = Array.new(1) { query[:text] }
            else
              query = {chat_id: params.message.chat.id, text: body.first}
            end
          
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
