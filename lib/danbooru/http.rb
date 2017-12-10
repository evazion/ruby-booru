require "active_support"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/inclusion"
require "connection_pool"
require "http"

class Danbooru::HTTP
  RETRY_CODES = [429, 502, 503, 504]

  def initialize(url, user: nil, pass: nil, connections: 10, timeout: 60, log: Logger.new(nil))
    @connections = connections
    @timeout = timeout
    @log = log

    @pool = ConnectionPool.new(size: @connections, timeout: @timeout) do
      connect(url, user, pass)
    end
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
      backoff(n)
      response = log_request(method, url, **options)
      n += 1
    end

    response
  end

  private
  def connect(url, user = nil, pass = nil)
    conn = HTTP::Client.new
    conn = conn.basic_auth(user: user, pass: pass) if user.present? && pass.present?
    conn = conn.accept("application/json")
    conn = conn.timeout(:global, read: 60, write: 60, connect: 60)
    conn = conn.use(:auto_inflate).headers("Accept-Encoding": "gzip")
    conn = conn.follow
    conn = conn.nodelay
    conn = conn.persistent(url)
    conn
  end

  def log_request(method, url, **options)
    response, duration = time_request(method, url, **options)
    log_response(response, method, duration)

    response
  end

  def time_request(method, url, **options)
    @pool.with do |conn|
      start = Time.now.to_f
      response = conn.request(method, url, **options).flush
      finish = Time.now.to_f

      duration = finish - start
      return response, duration
    end
  end

  def log_response(response, method, duration)
    @log.debug "http" do
      runtime = (response.headers["X-Runtime"].try(&:to_f) || 0) * 1000
      latency = (duration * 1000 - runtime)
      socket = response.connection.instance_variable_get("@socket").socket
      ip = socket.local_address.inspect_sockaddr rescue nil
      fd = socket.fileno rescue nil

      stats = "time=%-6s lag=%-6s ip=%s fd=%s" % ["#{runtime.to_i}ms", "+#{latency.to_i}ms", ip, fd]
      "#{stats} code=#{response.code} method=#{method.upcase} url=#{response.uri}"
    end
  end

  def backoff(n)
    max = 2 ** [n, 3].min
    backoff = rand(0.0..max)
    sleep backoff
  end
end
