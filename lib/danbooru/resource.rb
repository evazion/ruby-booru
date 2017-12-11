require "active_support"
require "active_support/core_ext/hash/keys"
require "retriable"

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

    def request(method, path = "/", options = {}, **params)
      options[:tries] ||= 1_000
      options[:max_interval] ||= 15
      options[:max_elapsed_time] ||= 300

      resp = nil
      Retriable.retriable(on: Danbooru::Response::TemporaryError, **options) do
        resp = booru.http.request(method, url + path, **params)
        resp = Danbooru::Response.new(self, resp)

        raise Danbooru::Response::TemporaryError if resp.failed? && resp.retry?
      end
    rescue Danbooru::Response::TemporaryError => e
      resp
    else
      resp
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
      request(:get, "/", params: { limit: 0 }, retries: 0).succeeded?
    end

    def first
      index(limit: 1, page: "a0").first
    end

    def last
      index(limit: 1, page: "b100000000").first
    end

    def partition(size)
      max = last.id + 1

      endpoints = max.step(0, -size).lazy + [0]
      subranges = endpoints.each_cons(2)
      subranges = subranges.map { |upper, lower| [lower, upper] }
      subranges
    end

    def all(workers: 10, jobs: 10, size: 1000, **params, &block)
      subranges = partition(size)

      results = subranges.pmap(workers: workers, jobs: jobs) do |from, to|
        response = each(from: from, to: to, **params, &block)
        response.to_a
      end

      results = results.flat_map(&:itself)
      results
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
      params = default_params.merge(params)
      n = to

      loop do
        params[:limit] = (n - from).clamp(0, params[:limit])
        return [] if params[:limit] == 0

        items = index(**params, page: "b#{n}")
        items.select! { |item| item.id >= from && item.id < to }
        items.each { |item| yield item }

        return items if items.empty? || items.size < params[:limit]
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
