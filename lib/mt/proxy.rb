require "mt/proxy/version"
require 'active_support/core_ext/module'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/numeric/time'
require 'digest/sha1'
require 'yaml'
require 'json'
require 'redis/namespace'

=begin

redis keys:
  hosts (list) - the list of all the proxies that are available
  <sha1>:via - public ip that was associated with a previous request
  <public_ip>:via - the proxy ip that has this public ip associated
  <proxy.host>:<proxy.port>:goes_as - public ip that is associated with a proxy

=end

module MT
  module Proxy extend self

    class NoProxyError < RuntimeError
    end

    mattr_accessor :namespace
    self.namespace = "proxy"

    mattr_accessor :association_ttl
    self.association_ttl = 3.minutes

    mattr_accessor :check_interval
    self.check_interval = 10.seconds

    attr :redis

    def redis=(connection)
      @redis = Redis::Namespace.new(namespace, :redis => connection)
    end

    def pick
      if proxy = new_proxy
        return proxy
      end

      raise(NoProxyError, "No proxy registered at `#{redis.inspect}'")
    end

    def register(address_with_port, public_ip)
      redis.setex("#{address_with_port}:goes_as", check_interval * 1.5, public_ip)
      redis.setex("#{public_ip}:via", check_interval * 1.5, address_with_port)
      redis.lrem("hosts", 0, address_with_port)
      redis.lpush("hosts", address_with_port)
    end

    def unregister(address_with_port, public_ip)
      redis.lrem "hosts", 0, address_with_port
      redis.del "#{address_with_port}:goes_as", "#{public_ip}:via"
    end


    def pick_for(*context)
      key = Digest::SHA1.hexdigest(context.to_json)

      if proxy = recently_used_proxy_for(key)
        return proxy
      end

      if proxy = new_association_for(key)
        return proxy
      end
      raise(NoProxyError, "No proxy registered at `#{redis.inspect}'")
    end

    private

    def new_proxy
      if proxy = redis.rpoplpush("hosts", "hosts")
        return URI.parse("http://#{proxy}")
      end
    end

    def new_association_for(key)
      if proxy = new_proxy
        public_ip = redis.get("#{proxy.host}:#{proxy.port}:goes_as")
        redis.setex("#{key}:via", association_ttl, public_ip)
        proxy
      end
    end


    def recently_used_proxy_for(key)

      if public_ip = redis.get("#{key}:via") and proxy = redis.get("#{public_ip}:via")
        return URI.parse("http://#{proxy}")
      end

    end

  end
end
