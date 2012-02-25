class Statsd
  class Stub < ::Statsd
    def send_to_socket(message)
      # do nothing in the stub
    end
  end
end
