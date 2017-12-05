require "active_support"
require "active_support/concern"
require "active_support/core_ext/object/inclusion"
require "active_support/core_ext/object/to_query"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/module/concerning"
require "rest-client"
require "json"

require "danbooru/model"

class Danbooru
  class Resource < RestClient::Resource
    class Error < StandardError; end
    attr_accessor :booru, :factory

    def initialize(url, options = {})
      @booru = options[:booru]
      @factory = options[:factory] || Danbooru::Model
      super(url, options)
    end

    def default_params
      { limit: 1000 }
    end

    concerning :HttpMethods do
      def backoff(n)
        backoff = 0.125 * rand(0..(2**min(n, 7) - 1))
        sleep backoff
      end

      def http_get(params, retries: 30)
        0.upto(retries) do |n|
          begin
            return self.get(params: params)
          rescue RestClient::RequestFailed => e
            if e.response.code.in?([429, 502, 503, 504])
              backoff(n)
              redo
            else
              return e.response
            end
          end
        end
      end

      def parse_response(response)
        data = JSON.parse(response.body)

        if response.code >= 400
          Danbooru::Model::Error.new(self, data)
        elsif data.is_a?(Array)
          data.map { |hash| factory.new(self, hash) }
        elsif data.is_a?(Hash)
          factory.new(self, data)
        else
          raise NotImplementedError
        end
      end
    end

    def search(**params)
      params = params.transform_keys { |k| :"search[#{k}]" }

      type = params.has_key?(:"search[order]") ? :page : :id
      all(by: type, **params)
    end

    def index(params = {})
      params = default_params.merge(params)
      resp = self.http_get(params)
      parse_response(resp)
    end

    def show(id)
      resp = self[id].get
      parse_response(resp)
    end

    def update(id, **params)
      resp = self[id].put(params)
      parse_response(resp)
    end

    def newest(since, limit = 50)
      items = index(limit: limit)
      items.select { |i| i.created_at > since }
    end

    def all(**params, &block)
      each(**params, &block).lazy
    end

    def each(by: :id, **params, &block)
      return enum_for(:each, by: by, **params) unless block_given?

      if by == :id
        each_by_id(**params, &block)
      else
        each_by_page(**params, &block)
      end
    end

    def each_by_id(from: 0, to: 100_000_000, **params)
      n = to

      loop do
        items = index(**params, page: "b#{n}")
        items.select! { |item| item.id >= from && item.id < to }
        items.each { |item| yield item }

        return [] if items.empty?
        n = items.last.id
      end
    end

    def each_by_page(from: 1, to: 5_000, **params)
      from.upto(to) do
        items = index(**params, page: from)
        items.each { |item| yield item }

        return [] if items.empty?
      end
    end

    def export(file = STDOUT)
      each do |model|
        file.puts model.to_json
      end
    end
  end
end
