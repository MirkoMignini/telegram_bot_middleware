require 'ostruct'

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
end