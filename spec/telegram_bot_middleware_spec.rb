require 'spec_helper'

describe TelegramBotMiddleware do
  
  let(:app) { ->(env) { [200, env, 'app'] } }
  let(:token) { '138381425:AAEXjzZx5U5wZmiKvFmHjdNMkXJqnkHnum4' }
  let(:host) { 'http://127.0.0.1:9292' }
  let(:middleware) {
    TelegramBotMiddleware.new(app) { |config|
      config.token = token
      config.host = host
    }
  }
  
  def init_middleware(&block)
    TelegramBotMiddleware.new(app, &block)
  end
  
  context 'Preliminary checks' do
    it 'has a version number' do
      expect(TelegramBotMiddleware::VERSION).not_to be nil
    end
  end
  
  context 'Configuration not valid' do
    it 'raise ArgumentError if token is null' do expect { init_middleware { |config| config.token = nil } }.to raise_error(ArgumentError) end
    it 'raise ArgumentError if token is empty' do expect { init_middleware { |config| config.token = '' } }.to raise_error(ArgumentError) end
    it 'raise ArgumentError if host is null' do expect { init_middleware { |config| config.token = token; config.host = nil } }.to raise_error(ArgumentError) end
    it 'raise ArgumentError if host is empty' do expect { init_middleware { |config| config.token = token; config.host = '' } }.to raise_error(ArgumentError) end
    it 'raise ArgumentError if get_updates is not valid' do expect { init_middleware { |config| config.token = token; config.host = host; config.get_updates = :not_valid } }.to raise_error(ArgumentError) end
  end
  
  context 'Configuration valid' do
    it 'initialize with correct parameters' do
      expect(middleware).to_not be nil
    end
  end
  
end
