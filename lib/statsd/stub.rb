class StatsD
  class Stub < ::StatsD
    def send_to_socket(message)
      # do nothing in the stub
    end
  end
end
