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
  
  def initialize(app, &_block)
    # save the app var
    @app = app
    
    # local cookies hash
    @cookies = Hash.new
    
    # create the config and populate passing do the block function
    @config = OpenStruct.new
    yield(@config) if block_given?
    
    # validate required input params
    raise ArgumentError.new("Config error: host can't be null || empty.") if @config.host.nil? || @config.host.empty?
    raise ArgumentError.new("Config error: token can't be null || empty.") if @config.token.nil? || @config.token.empty?
    
    # initialize persistent connection to telegram
    self.class.persistent_connection_adapter  pool_size: (@config.connection_pool_size || 2),
                                              keep_alive: (@config.connection_keep_alive || 30),
                                              force_retry: (@config.connection_force_retry || true)
    
    # if get_updates is empty set to :polling by default
    @config.get_updates ||= :polling

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
        send_to_telegram('setWebhook', {url: ''})
        
        # setup a thread with get_updates function
        start_get_updates_thread
      
      # setup webhook
      when :webhook
        send_to_telegram('setWebhook', {url: @config.webhook})
      
      # in this case get_updates is a non valid value
      else
        raise ArgumentError.new('Config error: get_updates must be :webhook || :polling.')
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
        response = send_to_telegram('getUpdates', {offset: @offset})
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
    request = Rack::Request.new(env)
    
    # if the request is a post to bot webhhok
    if request.post? and request.path == "/#{@config.token}"
      
      # in case someone already read it
      request.body.rewind
      # build an openstruct based on post params
      params = OpenStruct.from_json(request.body.read)
      
      log_debug("Message from chat: #{params}")
      
      if params['message']
        type = 'message'
        chat_id = params.message.chat.id
        env['QUERY_STRING'] = Rack::Utils.build_nested_query(params.message.to_h_nested)
      elsif params['inline_query']
        type = 'inline_query'
        chat_id = params.inline_query.id
        env['QUERY_STRING'] = Rack::Utils.build_nested_query(params.inline_query.to_h_nested)
      end
      
      # build command based on message
      command = get_command(params)
      
      # transform the POST in GET
      env['PATH_INFO'] = command
      env['REQUEST_METHOD'] = 'GET'
      env['REQUEST_URI'] = "https://#{request.host}#{command}"
      
      # if in cache a cookie for this chat was present add to the header
      env['HTTP_COOKIE'] = @cookies[chat_id] if @cookies.include?(chat_id)
      
      # call the rack stack
      status, headers, body = @app.call(env)
      
      #body = body.body[0] if body.class == Rack::BodyProxy
      #puts body.class
      #puts body
      
      # try to send to telegram only if no errors
      if status == 200 || status == '200'
        
        # if the call setted a cookie save to local cache
        @cookies[chat_id] = headers['Set-Cookie'] if headers.include?('Set-Cookie')
        
        if type == 'message'
          case headers['Content-Type'].split(';').first
            when 'text/html', 'application/json'          
              if body.is_a? Hash
                process_hash_message(body.clone, params)
                body = Array.new(1) { '' }
                headers['Content-Length'] = '0'
              else
                body.each do |data|
                  begin
                    #TODO: add better json parsing to support symbols too
                    process_hash_message(JSON.parse(data.gsub('=>', ':')), params)
                  rescue
                    send_to_telegram('sendMessage', {chat_id: chat_id, text: data})
                  end
                end
              end

            when /(^image\/)/
              send_to_telegram('sendPhoto', {chat_id: chat_id, photo: File.new(body)})

            when /(^audio\/)/
              send_to_telegram('sendAudio', {chat_id: chat_id, audio: File.new(body)})

            when /(^video\/)/
              send_to_telegram('sendVideo', {chat_id: chat_id, video: File.new(body)})          
          end
        elsif type == 'inline_query'
          send_to_telegram('answerInlineQuery', {inline_query_id: chat_id, results: body[:results].to_json})
          body = Array.new(1) { '' }
          headers['Content-Length'] = '0'
        end
      end
      
      # return result
      [status, headers, body]
    else
      # normal rack flow - not a bot call
      @app.call(env)
    end
  end
  
  # build command based on message
  def get_command(params)
    if params['message']
      unless params.message['text'].nil?
        # build path based on message
        # - get only message part of post params
        # - remove empty chars from beginning || end (strip)
        # - replace first sequence of spaces with /
        # - encode as uri
        command = URI.escape(params.message.text.strip.sub(/\s+/, '/'))
        # - add first / if not present
        command = "/#{command}" unless command.start_with?('/')
        return command
      else
        %w(audio document photo sticker video voice contact location new_chat_participant left_chat_participant new_chat_title new_chat_photo delete_chat_photo group_chat_created).each do |type|
          unless params.message[type].nil?
            return "/#{type}"
          end
        end
      end
    elsif params['inline_query']
      return '/inline_query'
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
    message[:chat_id] = params.message.chat.id unless message.include?(:chat_id) || message.include?('chat_id')
    
    ['reply_markup', :reply_markup].each do |item|
      message[item] = message[item].to_json if message.include?(item)
    end
    
    ['photo', :photo, 'audio', :audio, 'video', :video].each do |item|
      message[item] = File.new(message[item]) if message.include?(item)
    end
    
    if message.include?(:text) || message.include?('text')
      send_to_telegram('sendMessage', message)
    elsif (message.include?(:latitude) and message.include?(:longitude)) || (message.include?('latitude') and message.include?('longitude'))
      send_to_telegram('sendLocation', message)
    elsif message.include?(:photo) || message.include?('photo')
      send_to_telegram('sendPhoto', message)
    elsif message.include?(:audio) || message.include?('audio')
      send_to_telegram('sendAudio', message)      
    elsif message.include?(:video) || message.include?('video')
      send_to_telegram('sendVideo', message)
    else
      # TODO: invalid query
    end
  end
  
  def send_to_telegram(path, query)
    log_debug("Sending to chat: #{path} - #{query}")
    self.class.post("/bot#{@config.token}/#{path}", query: query)
    # TODO check response error and return response
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
  
  # TODO: to fix env
  def log(level, message)
    #return if @env.nil?
    #if @env['rack.logger']
    #  @env['rack.logger'].send(level, message)
    #else
    #  @env['rack.errors'].write(message)
    #end
  end
end
