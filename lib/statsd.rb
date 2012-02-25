require 'socket'

# = StatsD: A StatsD client (https://github.com/etsy/statsd)
#
# @example Set up a global StatsD client for a server on localhost:9125
#   $statsd = StatsD.new 'localhost', 8125
# @example Send some stats
#   $statsd.increment 'garets'
#   $statsd.timing 'glork', 320
# @example Use {#time} to time the execution of a block
#   $statsd.time('account.activate') { @account.activate! }
# @example Create a namespaced statsd client and increment 'account.activate'
#   statsd = StatsD.new('localhost').tap{|sd| sd.namespace = 'account'}
#   statsd.increment 'activate'
class StatsD
  if defined?(::SystemTimer)
    Timeout = ::SystemTimer
  else
    require 'timeout'
  end

  # A namespace to prepend to all statsd calls.
  attr_reader :namespace

  # StatsD host. Defaults to 127.0.0.1.
  attr_accessor :host

  # StatsD port. Defaults to 8125.
  attr_accessor :port

  class << self
    # Set to a standard logger instance to enable debug logging.
    attr_reader :logger

    def logger=(logger) #:nodoc:
      @logger = logger
    end
  end

  # @param [String] host your statsd host
  # @param [Integer] port your statsd port
  def initialize(host = '127.0.0.1', port = 8125)
    self.host, self.port = host, port
    @prefix = nil
    @socket = UDPSocket.new
  end

  def namespace=(namespace) #:nodoc:
    @namespace = namespace
    @prefix = "#{namespace}."
  end

  def host=(host) #:nodoc:
    @host = host || '127.0.0.1'
  end

  def port=(port) #:nodoc:
    @port = port || 8125
  end

  # Sends an increment (count = 1) for the given stat to the statsd server.
  #
  # @param [String] stat stat name
  # @param [Numeric] sample_rate sample rate, 1 for always
  # @see #count
  def increment(stat, sample_rate=1)
    count stat, 1, sample_rate
  end

  # Sends a decrement (count = -1) for the given stat to the statsd server.
  #
  # @param [String] stat stat name
  # @param [Numeric] sample_rate sample rate, 1 for always
  # @see #count
  def decrement(stat, sample_rate=1)
    count stat, -1, sample_rate
  end

  # Sends an arbitrary count for the given stat to the statsd server.
  #
  # @param [String] stat stat name
  # @param [Integer] count count
  # @param [Numeric] sample_rate sample rate, 1 for always
  def count(stat, count, sample_rate=1)
    send_stats stat, count, :c, sample_rate
  end

  # Sends an arbitary gauge value for the given stat to the statsd server.
  #
  # This is useful for recording things like available disk space,
  # memory usage, and the like, which have different semantics than
  # counters.
  #
  # @param [String] stat stat name.
  # @param [Numeric] gauge value.
  # @param [Numeric] sample_rate sample rate, 1 for always
  # @example Report the current user count:
  #   $statsd.gauge('user.count', User.count)
  def gauge(stat, value, sample_rate=1)
    send_stats stat, value, :g, sample_rate
  end

  # Sends a timing (in ms) for the given stat to the statsd server. The
  # sample_rate determines what percentage of the time this report is sent. The
  # statsd server then uses the sample_rate to correctly track the average
  # timing for the stat.
  #
  # @param [String] stat stat name
  # @param [Integer] ms timing in milliseconds
  # @param [Numeric] sample_rate sample rate, 1 for always
  def timing(stat, ms, sample_rate=1)
    send_stats stat, ms, :ms, sample_rate
  end

  # Reports execution time of the provided block using {#timing}.
  #
  # @param [String] stat stat name
  # @param [Numeric] sample_rate sample rate, 1 for always
  # @yield The operation to be timed
  # @see #timing
  # @example Report the time (in ms) taken to activate an account
  #   $statsd.time('account.activate') { @account.activate! }
  def time(stat, sample_rate=1)
    time_in_ms, result = benchmark{ yield }
    timing(stat, time_in_ms, sample_rate)
    result
  end

private

  def send_stats(stat, delta, type, sample_rate=1)
    # Replace Ruby module scoping with '.' and reserved chars (: | @) with underscores.
    stat = stat.to_s.gsub('::', '.').tr(':|@', '_')

    if sample_rate == 1 or rand < sample_rate
      rate = "|@#{sample_rate}" unless sample_rate == 1
      message = "#{@prefix}#{stat}:#{delta}|#{type}#{rate}"
      send_to_socket(message)
    end
  end

  def send_to_socket(message)
    logger.debug "StatsD: #{message}"
    timeout{ @socket.send(message, 0, @host, @port) }
  rescue Timeout::Error, SocketError, IOError, SystemCallError => error
    logger.error "StatsD: #{error.class} #{error.message}"
  end

  # Benchmarks a block to get the time in ms it took, returning the return
  # value of the block as well.
  def benchmark
    start_time = Time.now
    result = yield

    [((Time.now - start_time) * 1000).round, result]
  end

  def timeout
    Timeout.timeout(0.1){ yield }
  end

  def logger
    if self.class.logger
      self.class.logger
    else
      @default_logger ||= Logger.new("/dev/null")
    end
  end
end
