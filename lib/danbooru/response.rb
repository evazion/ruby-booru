require "active_support"
require "active_support/core_ext/module/delegation"

class Danbooru
  class Response
    attr_reader :model, :json, :response
    delegate_missing_to :model

    def initialize(resource, response)
      @response = response
      @json = JSON.parse(response.body)

      if failed?
        @model = Danbooru::Model.new(resource, json)
      elsif json.is_a?(Array)
        @model = json.map { |item| resource.factory.new(resource, item) }
      elsif json.is_a?(Hash)
        @model = resource.factory.new(resource, json)
      else
        raise RuntimeError.new("Unrecognized response type (#{json.class})")
      end
    end

    def error
      return nil unless failed?

      "#{response.code} #{RestClient::STATUSES[response.code]}: #{message}"
    end

    def failed?
      response.code >= 400
    end

    def succeeded?
      !failed?
    end
  end
end
