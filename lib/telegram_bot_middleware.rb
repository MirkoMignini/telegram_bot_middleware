require 'rack'
require 'uri'
require 'http'
require 'httmultiparty'
require 'persistent_httparty'
require_relative 'ostruct_nested'
require_relative 'telegram_bot_middleware/version'

class TelegramBotMiddleware
  include HTTMultiParty
  base_uri 'https://api.telegram.org'
  persistent_connection_adapter pool_size: 1,
                                keep_alive: 30,
                                force_retry: true
  
  def initialize(app, &block)
    # save the app var
    @app = app
    
    puts 'Initializing...'
    
    # create the config and populate passing do the block function
    @config = OpenStruct.new
    yield(@config) if block_given?

    # setup webhook
    if @config.webhook.nil?
      @config.host = "#{@config.host}/" unless @config.host.end_with?('/')
      @config.webhook = "#{@config.host}#{@config.token}"
    end
    
    # setup telegram messages input
    case @config.get_updates
      
      # setup polling
      when :polling
        # clear the webhook in case was set in the past
        send_to_bot('setWebhook', {url: ''})
        
        # setup a thread with get_updates function
        start_get_updates_thread
      
      # setup webhook
      when :webhook
        send_to_bot('setWebhook', {url: @config.webhook})
      
      # in this case get_updates is a non valid value
      else
        raise ArgumentError.new('Config error: get_updates must be :webhook or :polling.')
    end
  end
  
  def start_get_updates_thread
    # start a new thread
    Thread.new do
      # the initial offset is always 0
      @offset = 0      
      # wait 5 seconds to don't risk to post message too early when the app is not still up
      sleep 5
      # loop forever
      loop do
        # call the getUpdates telegram function
        response = send_to_bot('getUpdates', {offset: @offset})
        # enumerate the results
        response.to_hash['result'].each do |data|
          # create an update message from the post data
          update = OpenStruct.new(data)
          # store the last offset +1 but ensure that is not lower than the already stored
          @offset = (update.update_id + 1) if update.update_id + 1 > @offset
          # simulate a post to itself
          HTTP.post @config.webhook, json: update.to_h_nested
        end
      end
    end
  end

  # necessary for thread safe
  def call(env)
    dup._call(env)
  end
  
  def _call(env)
    # retrieve the request object
    req = Rack::Request.new(env)
    
    # if the request is a post to bot webhhok
    if req.post? and req.path == "/#{@config.token}"
      
      # in case someone already read it
      req.body.rewind
      # build an openstruct based on post params
      params = OpenStruct.from_json(req.body.read)
      
      # build path based on message
      # - get only message part of post params
      # - remove empty chars from beginning or end (strip)
      # - replace first sequence of spaces with /
      # - encode as uri
      path = URI.escape(params.message.text.strip.sub(/\s+/, '/'))
      # - add first / if not present
      path = "/#{path}" unless path.start_with?('/')
      
      # build the querystring using message but nested
      query_string = Rack::Utils.build_nested_query(params.message.to_h_nested)
      
      # transform the POST in GET
      env['PATH_INFO'] = path
      env['QUERY_STRING'] = query_string
      env['REQUEST_METHOD'] = 'GET'
      env['REQUEST_URI'] = "https://#{req.host}#{path}"
      # TODO use update(hash) { |name, old_value, new_value| }
      
      # call the rack stack
      status, headers, body = @app.call(env)
      
      if status == 200 or status == '200'
        
        case headers['Content-Type'].split(';').first
          when 'text/html', 'application/json'          
            
            if body.is_a? Hash
            
              query = body.clone
              query[:chat_id] = params.message.chat.id unless query.include?(:chat_id)
              query[:reply_markup] = query[:reply_markup].to_json if query.include?(:reply_markup)
              
              body = Array.new(1) { '' }
              
              if query.include?(:text)
                send_to_bot('sendMessage', query)
              elsif query.include?(:latitude) and query.include?(:longitude)
                send_to_bot('sendLocation', query)
              elsif query.include?(:photo)
                send_to_bot('sendPhoto', query)
              elsif query.include?(:audio)
                send_to_bot('sendAudio', query)              
              elsif query.include?(:video)
                send_to_bot('sendVideo', query)              
              else
                # TODO: invalid query
              end
              
            else
              body.each do |data|
                send_to_bot('sendMessage', {chat_id: params.message.chat.id, text: data})
              end
            end
        
          when /(^image\/)/
            send_to_bot('sendPhoto', {chat_id: params.message.chat.id, photo: File.new(body)})
        
          when /(^audio\/)/
            send_to_bot('sendAudio', {chat_id: params.message.chat.id, audio: File.new(body)})
          
          when /(^video\/)/
            send_to_bot('sendVideo', {chat_id: params.message.chat.id, video: File.new(body)})          
        end
      end
      
      # return result
      [status, headers, body]
    else
      # normal rack flow - not a bot call
      @app.call(env)
    end
  end
  
  def send_to_bot(path, query)
    response = self.class.post("/bot#{@config.token}/#{path}", query: query)
    # TODO check respobse error
  end
end
