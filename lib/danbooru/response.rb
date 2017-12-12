require "active_support"
require "active_support/core_ext/module/delegation"

class Danbooru
  class Response
    class TemporaryError < StandardError; end

    attr_reader :model, :json, :resource, :response
    delegate_missing_to :model

    def initialize(resource, response)
      @resource, @response = resource, response

      if failed?
        @model = Danbooru::Model.new(json, resource)
      elsif json.is_a?(Array)
        @model = json.map { |item| factory.new(item, resource) }
      elsif json.is_a?(Hash)
        @model = factory.new(json, resource)
      else
        raise RuntimeError.new("Unrecognized response type (#{json.class})")
      end
    end

    def json
      @json ||=
        case @response.mime_type
          when "application/json" then JSON.parse(@response.body)
          else { message: "ERROR: non-JSON response (#{@response.mime_type})" }
        end
    end

    def to_json(options = nil)
      json.to_json(options)
    end

    def factory
      name = resource.name
      resource.booru.factory[name] || "Danbooru::Model::#{name.singularize.capitalize}".safe_constantize || Danbooru::Model
    end

    def error
      return nil unless failed?

      "#{response.status}: #{message}"
    end

    def failed?
      response.code >= 400
    end

    def succeeded?
      !failed?
    end

    def timeout?
      response.code == 500 && message == "ERROR:  canceling statement due to statement timeout\n"
    end

    def retry?
      [429, 502, 503, 504].include?(response.code) || timeout?
    end
  end
end
