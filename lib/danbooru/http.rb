require "active_support"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/inclusion"
require "http"

class Danbooru::HTTP
  RETRY_CODES = [429, 502, 503, 504]
  attr_reader :conn

  def initialize(url, user: nil, pass: nil, log: Logger.new(nil))
    @log = log

    @conn = HTTP::Client.new
    @conn = @conn.basic_auth(user: user, pass: pass) if user.present? && pass.present?
    @conn = @conn.accept("application/json")
    @conn = @conn.timeout(:global, read: 60, write: 60, connect: 60)
    @conn = @conn.use(:auto_inflate).headers("Accept-Encoding": "gzip")
    @conn = @conn.follow
    @conn = @conn.nodelay
    @conn = @conn.persistent(url)
  end

  %i[get put post delete].each do |method|
    define_method(method) do |url, **options|
      request(method, url, **options)
    end
  end

  def request(method, url, retries: 30, retry_codes: RETRY_CODES, **options)
    response = log_request(method, url, **options)

    n = 0
    while n < retries && response.code.in?(retry_codes)
      response.flush
      backoff(n)
      response = log_request(method, url, **options)
      n += 1
    end

    response
  end

  private
  def log_request(method, url, **options)
    start = Time.now.to_f
    response = conn.request(method, url, **options)
    finish = Time.now.to_f

    @log.debug "http" do
      runtime = ((response.headers["X-Runtime"].try(&:to_f) || 0) * 1000)
      latency = ((finish - start) * 1000) - runtime
      socket = response.connection.instance_variable_get("@socket").socket

      stats = "time=%-6s lag=%-6s ip=%s fd=%i" % ["#{runtime.to_i}ms", "+#{latency.to_i}ms", socket.local_address.inspect_sockaddr, socket.fileno]
      "#{stats} code=#{response.code} method=#{method.upcase} url=#{response.uri}"
    end

    response
  end

  def backoff(n)
    max = 2 ** [n, 3].min
    backoff = rand(0.0..max)
    sleep backoff
  end
end
