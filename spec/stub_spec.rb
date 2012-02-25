require 'helper'

describe Statsd::Stub do
  class Statsd
    # we need to stub this
    attr_accessor :socket
  end

  before do
    @stub = Statsd::Stub.new
    @stub.socket = MiniTest::Mock.new
  end

  it "should never try to send any data" do
    # not setting expectations on the mock so if the socket is used it will
    # throw an error
    @stub.increment('foobar')
  end
end
