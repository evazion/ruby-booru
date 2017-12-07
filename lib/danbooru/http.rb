require "active_support"
require "active_support/core_ext/object/inclusion"
require "http"

class Danbooru::HTTP
  attr_reader :conn

  def initialize(url, user: nil, pass: nil, log: Logger.new(nil))
    @log = log
    @conn = HTTP.basic_auth(user: user, pass: pass)
    @conn = @conn.accept("application/json")
    @conn = @conn.timeout(:global, read: 60, write: 60, connect: 60)
    @conn = @conn.use(:auto_inflate)
    @conn = @conn.follow
    @conn = @conn.nodelay
    @conn = @conn.persistent(url)
  end

  def request(method, url, retries: 30, **options)
    0.upto(retries) do |n|
      response = log_request(method, url, **options)

      if response.code.in?([429, 502, 503, 504]) && retries > 0
        backoff(n)
        redo
      else
        return response
      end
    end
  end

  private
  def log_request(method, url, **options)
    start = Time.now.to_f
    response = conn.request(method, url, **options)
    finish = Time.now.to_f

    @log.debug do
      runtime = ((response.headers["X-Runtime"].try(&:to_f) || 0) * 1000).to_i
      elapsed = ((finish - start) * 1000).to_i

      "[http] #{response.status}: #{method.upcase} #{response.uri} (#{runtime}ms, +#{elapsed - runtime}ms)"
    end

    response
  end

  def backoff(n)
    backoff = rand(0.0 .. 2**min(n, 3))
    sleep backoff
  end
end
