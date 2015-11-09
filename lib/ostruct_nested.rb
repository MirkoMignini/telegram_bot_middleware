require 'ostruct'
require 'json'

class OpenStruct 
  def to_h_nested
    hash = self.to_h
    hash.each do |key, value|
      if value.is_a? OpenStruct
        hash[key] = value.to_h_nested
      end
    end
    hash
  end
  
  def self.from_json(json_string)
    JSON.parse(json_string, object_class: OpenStruct)
  end
end