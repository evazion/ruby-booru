require "active_support"
require "active_support/core_ext/module/delegation"
require "ostruct"

class Danbooru
  class Model
    attr_reader :api, :attributes
    delegate_missing_to :attributes

    def initialize(attributes, api = nil)
      self.attributes = attributes
      @api = api
    end

    def attributes=(attributes)
      @attributes = cast_attributes(attributes)
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
      OpenStruct.new(attributes.map do |name, value|
        [name, cast_attribute(name, value)]
      end.to_h)
    end

    def cast_attribute(name, value)
      if name =~ /_at$/
        Time.parse(value) rescue nil
      elsif name =~ /(^|_)url$/
        Addressable::URI.parse(value)
      elsif value.is_a?(Array)
        value.map { |item| Danbooru::Model.new(item, nil) }
      else
        value
      end
    end
  end
end
