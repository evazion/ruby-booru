require "active_support"
require "active_support/core_ext/hash/keys"
require "json"

require "danbooru/model"

class Danbooru
  class Resource
    class Error < StandardError; end
    attr_accessor :booru, :name, :url, :factory

    def initialize(name, booru)
      @name = name
      @booru = booru
      @url = booru.host.to_s + "/" + name
    end

    def default_params
      { limit: 1000 }
    end

    def request(method, path = "/", **options)
      resp = booru.http.request(method, url + path, **options)
      Danbooru::Response.new(self, resp)
    end

    def index(params = {}, options = {})
      request(:get, "/", params: default_params.merge(params), **options)
    end

    def show(id, params = {}, options = {})
      request(:get, "/#{id}", params: default_params.merge(params), **options)
    end

    def update(id, params = {}, options = {})
      request(:put, "/#{id}", json: params, **options)
    end

    def search(**params)
      params = params.transform_keys { |k| :"search[#{k}]" }

      type = params.has_key?(:"search[order]") ? :page : :id
      all(by: type, **params)
    end

    def ping
      request(:get, "/", retries: 0).succeeded?
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
      from.upto(to) do |n|
        items = index(**params, page: n)
        items.each { |item| yield item }

        return [] if items.empty?
      end
    end
  end
end
