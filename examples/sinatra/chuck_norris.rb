require 'uri'
require 'net/http'
require 'json'
require_relative 'example_init'

get '*' do
  JSON.parse(Net::HTTP.get(URI('http://api.icndb.com/jokes/random')))['value']['joke']
end