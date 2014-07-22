ENV["RACK_ENV"] = "test"

$: << File.expand_path("../../lib", __FILE__)

require 'timecop'
require 'rspec/its'
require 'mt/proxy'
require 'mock_redis'




RSpec.configure do |config|

  config.before :each do
    MT::Proxy.redis = MockRedis.new
  end

  config.after :each do
    Timecop.return
  end

end



def register_first_proxy
  MT::Proxy.register "127.0.0.1:3128", "0.0.0.1"
end

def register_second_proxy
  MT::Proxy.register "127.0.0.1:3130", "0.0.0.2"
end

def unregister_first_proxy
  MT::Proxy.unregister "127.0.0.1:3128", "0.0.0.1"
end
