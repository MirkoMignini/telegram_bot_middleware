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
    @env = nil
    
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
    @env = env
    
    # retrieve the request object
    req = Rack::Request.new(@env)
    
    # if the request is a post to bot webhhok
    if req.post? and req.path == "/#{@config.token}"
      
      # in case someone already read it
      req.body.rewind
      # build an openstruct based on post params
      params = OpenStruct.from_json(req.body.read)
      
      log_debug("Message from chat: #{params}")

      path = nil
      unless params.message['text'].nil?
        # build path based on message
        # - get only message part of post params
        # - remove empty chars from beginning or end (strip)
        # - replace first sequence of spaces with /
        # - encode as uri
        path = URI.escape(params.message.text.strip.sub(/\s+/, '/'))
        # - add first / if not present
        path = "/#{path}" unless path.start_with?('/')
      else
        %w(audio document photo sticker video voice contact location new_chat_participant left_chat_participant new_chat_title new_chat_photo delete_chat_photo group_chat_created).each do |type|
          unless params.message[type].nil?
            path = "/#{type}"
            break
          end
        end
      end
      
      # build the querystring using message but nested
      query_string = Rack::Utils.build_nested_query(params.message.to_h_nested)
      
      # transform the POST in GET
      @env['PATH_INFO'] = path
      @env['QUERY_STRING'] = query_string
      @env['REQUEST_METHOD'] = 'GET'
      @env['REQUEST_URI'] = "https://#{req.host}#{path}"
      # TODO use update(hash) { |name, old_value, new_value| }
      
      # call the rack stack
      status, headers, body = @app.call(@env)
      
      if status == 200 or status == '200'
        
        case headers['Content-Type'].split(';').first
          when 'text/html', 'application/json'          
            if body.is_a? Hash
              process_hash_message(body.clone, params)
              body = Array.new(1) { '' }
            else
              body.each do |data|
                begin
                  #TODO: add better json parsing to support symbols too
                  process_hash_message(JSON.parse(data.gsub('=>', ':')), params)
                rescue
                  send_to_bot('sendMessage', {chat_id: params.message.chat.id, text: data})
                end
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
  
  def process_hash_message(message, params)
    if (message.include?(:multiple) && message[:multiple].is_a?(Array))
      message[:multiple].each { |item| process_json_message(item, params) }
    elsif (message.include?('multiple') && message['multiple'].is_a?(Array))
      message['multiple'].each { |item| process_json_message(item, params) }
    else
      process_json_message(message, params)            
    end
  end
  
  def process_json_message(message, params)
    message[:chat_id] = params.message.chat.id unless message.include?(:chat_id) or message.include?('chat_id')
    
    message[:reply_markup] = message[:reply_markup].to_json if message.include?(:reply_markup)
    message['reply_markup'] = message['reply_markup'].to_json if message.include?('reply_markup')
    
    ['photo', :photo, 'audio', :audio, 'video', :video].each do |item|
      message[item] = File.new(message[item]) if message.include?(item)
    end
    
    if message.include?(:text) or message.include?('text')
      send_to_bot('sendMessage', message)
    elsif (message.include?(:latitude) and message.include?(:longitude)) or (message.include?('latitude') and message.include?('longitude'))
      send_to_bot('sendLocation', message)
    elsif message.include?(:photo) or message.include?('photo')
      send_to_bot('sendPhoto', message)
    elsif message.include?(:audio) or message.include?('audio')
      send_to_bot('sendAudio', message)      
    elsif message.include?(:video) or message.include?('video')
      send_to_bot('sendVideo', message)
    else
      # TODO: invalid query
    end  
  end
  
  def log_error(exception)
    message = "Error: #{exception.message}\n#{exception.backtrace.join("\n")}\n"
    log(:error, message)
  end

  def log_info(message)
    log(:info, message)
  end

  def log_debug(message)
    log(:debug, message)
  end
  
  def log(level, message)
    return if @env.nil?
    if @env['rack.logger']
      @env['rack.logger'].send(level, message)
    else
      @env['rack.errors'].write(message)
    end
  end
  
  def send_to_bot(path, query)
    log_debug("Sending to chat: #{path} - #{query}")
    response = self.class.post("/bot#{@config.token}/#{path}", query: query)
    # TODO check response error and return response
  end
end
