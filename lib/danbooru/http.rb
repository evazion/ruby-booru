require "active_support"
require "active_support/core_ext/object/inclusion"
require "http"

class Danbooru::HTTP
  attr_reader :conn

  def initialize(url, user: nil, pass: nil)
    @conn = HTTP.basic_auth(user: user, pass: pass)
    @conn = @conn.accept("application/json")
    @conn = @conn.timeout(:global, read: 60, write: 60, connect: 60)
    @conn = @conn.use(:auto_inflate)
    @conn = @conn.follow
    @conn = @conn.nodelay
    @conn = @conn.persistent(url)
  end

  def request(method = :get, url = "/", params: {}, retries: 30)
    0.upto(retries) do |n|
      response = conn.request(method, url, params: params)

      if response.code.in?([429, 502, 503, 504]) && retries > 0
        backoff(n)
        redo
      else
        return response
      end
    end
  end

  private
  def backoff(n)
    backoff = rand(0.0 .. 2**min(n, 3))
    sleep backoff
  end
end
