require "active_support"
require "active_support/core_ext/module/delegation"
require "ostruct"

class Danbooru
  class Model
    attr_reader :api, :attributes
    delegate_missing_to :attributes

    def initialize(api, attributes)
      @api = api
      self.attributes = attributes
    end

    def attributes=(attributes)
      @attributes = OpenStruct.new(cast_attributes(attributes.to_h))
    end

    def resource_name
      api.name.singularize
    end

    def update(params = {}, options = {})
      self.attributes = api.update(id, { resource_name => params }, options)
      self
    end

    def url
      "#{api.url}/#{id}"
    end

    def shortlink
      "#{resource_name} ##{id}"
    end

    protected

    def cast_attributes(attributes)
      attributes.map do |name, value|
        [name, cast_attribute(name, value)]
      end.to_h
    end

    def cast_attribute(name, value)
      case name
      when /_at$/
        Time.parse(value) rescue nil
      when /_url$/
        Addressable::URI.parse(value)
      else
        value
      end
    end
  end
end
