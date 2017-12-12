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
      response = api.update(id, { resource_name => params }, options)
      self.attributes = response.model.as_json
      self
    end

    def url
      "#{api.url}/#{id}"
    end

    def shortlink
      "#{resource_name} ##{id}"
    end

    def as_json(options = {})
      attributes.to_h.transform_values(&method(:serialize_attribute))
    end

    def pretty_print(printer)
      printer.pp(attributes.to_h)
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
      elsif value.is_a?(Hash)
        Danbooru::Model.new(value, nil)
      elsif value.is_a?(Array)
        value.map { |item| cast_attribute(name, item) }
      else
        value
      end
    end

    def serialize_attribute(value)
      case value
      when Time, Addressable::URI
        value.to_s
      when Danbooru::Model
        value.as_json
      when Array
        value.map(&method(:serialize_attribute))
      else
        value
      end
    end
  end
end
