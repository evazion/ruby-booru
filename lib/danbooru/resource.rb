require "active_support"
require "active_support/core_ext/hash/keys"
require "json"

require "danbooru/model"

class Danbooru
  class Resource
    class Error < StandardError; end
    attr_accessor :booru, :factory, :url

    def initialize(url = "/", booru:, factory: Danbooru::Model)
      @booru, @factory, @url = booru, factory, booru.host.to_s + url
    end

    def default_params
      { limit: 1000 }
    end

    def search(**params)
      params = params.transform_keys { |k| :"search[#{k}]" }

      type = params.has_key?(:"search[order]") ? :page : :id
      all(by: type, **params)
    end

    def index(params = {}, options = {})
      resp = booru.http.request(:get, url, params: default_params.merge(params), **options)
      Danbooru::Response.new(self, resp)
    end

    def show(id, params = {}, options = {})
      resp = booru.http.request(:get, url + "/#{id}", params: default_params.merge(params), **options)
      Danbooru::Response.new(self, resp)
    end

    def update(id, params = {}, options = {})
      resp = booru.http.request(:put, url + "/#{id}", json: params, **options)
      Danbooru::Response.new(self, resp)
    end

    def newest(since, limit = 50)
      items = index(limit: limit)
      items.select { |i| i.created_at > since }
    end

    def ping
      index({ limit: 1 }, retries: 0).succeeded?
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
