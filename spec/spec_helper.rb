ENV["RACK_ENV"] = "test"

$: << File.expand_path("../../lib", __FILE__)

require 'timecop'
require 'rspec/its'
require 'mt/proxy'
require 'mock_redis'




RSpec.configure do |config|

  config.before :each do
    MT::Proxy.redis = MockRedis.new
    $PROXIES.each do |proxy|
      proxy[:in_use] = false
      proxy.delete(:pool)
    end
  end

  config.after :each do
    Timecop.return
  end

end


# MT::Proxy.unregister

def register_proxy(proxy={})

  proxy_address = proxy.fetch(:proxy_address)
  public_address = proxy.fetch(:public_address)
  old_pool, MT::Proxy.pool = MT::Proxy.pool, proxy.fetch(:pool, MT::Proxy.pool)
  MT::Proxy.register proxy_address, public_address
  proxy[:in_use] = true
ensure
  MT::Proxy.pool = old_pool
end

def unregister_proxy(proxy={})

  proxy_address = proxy.fetch(:proxy_address)
  public_address = proxy.fetch(:public_address)
  old_pool, MT::Proxy.pool = MT::Proxy.pool, proxy.fetch(:pool, MT::Proxy.pool)

  MT::Proxy.unregister proxy_address, public_address
  proxy[:in_use] = false
ensure
  MT::Proxy.pool = old_pool
end

$PROXIES  = 10.times.map do |n|
    { proxy_address: "127.0.0.1:#{n}", public_address: "172.16.0.#{n}", in_use: false}
end


def unused_proxy
  $PROXIES.find { |proxy| not proxy[:in_use] } or raise "No more proxies"
end



# def register_first_proxy(pool=MT::Proxy.pool)
#   register_proxy pool, "127.0.0.1:3128", "0.0.0.1"
# end

# def register_second_proxy(pool=MT::Proxy.pool)
#   register_proxy pool, "127.0.0.1:3130", "0.0.0.2"
# end

# def unregister_first_proxy(pool=MT::Proxy.pool)
#   unregister_proxy pool, "127.0.0.1:3128", "0.0.0.1"
# end
