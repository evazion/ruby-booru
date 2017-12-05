require "active_support"
require "active_support/core_ext/object/to_query"
require "active_support/core_ext/hash/keys"
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

    def search(**params)
      params = params.transform_keys { |k| :"search[#{k}]" }

      type = params.has_key?(:"search[order]") ? :page : :id
      all(by: type, **params)
    end

    def index(params = {})
      params = default_params.merge(params)
      resp = self.get(params: params)

      data = JSON.parse(resp.body)
      if data.is_a?(Array)
        data.map { |hash| factory.new(self, hash) }
      elsif data.is_a?(Hash)
        factory.new(self, data)
      else
        raise NotImplementedError
      end
    end

    def show(id)
      resp = self[id].get
      hash = JSON.parse(resp.body)
      factory.new(self, hash)
    end

    def update!(id, **params)
      resp = self[id].put(params)

      if resp.code == 200
        hash = JSON.parse(resp.body)
        factory.new(self, hash)
      else
        raise Danbooru::Resource::Error.new(resp)
      end
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

        break if items.empty?
        n = items.last.id
      end
    end

    def each_by_page(from: 1, to: 5_000, **params)
      loop do
        items = index(**params, page: from)
        items.each { |item| yield item }
        from += 1

        break if items.empty? || from > to
      end
    end

    def export(file = STDOUT)
      each do |model|
        file.puts model.to_json
      end
    end
  end
end
