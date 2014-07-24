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

    mattr_accessor :hosts_key
    self.hosts_key = "no-vpn-hosts"

    attr :redis

    def redis=(connection)
      @redis = Redis::Namespace.new(namespace, :redis => connection)
    end

    def pick(options = {})
      if proxy = new_proxy(options)
        return proxy
      end

      raise(NoProxyError, "No proxy registered at `#{redis.inspect}'")
    end

    def register(address_with_port, public_ip)
      renew(address_with_port, public_ip)
      redis.lrem(hosts_key, 0, address_with_port)
      redis.lpush(hosts_key, address_with_port)
    end

    def renew(address_with_port, public_ip)
      guard_time = (check_interval * 1.5).round
      redis.setex("#{address_with_port}:goes_as", guard_time, public_ip)
      redis.setex("#{public_ip}:via", guard_time, address_with_port)
    end

    def unregister(address_with_port, public_ip)
      redis.lrem hosts_key, 0, address_with_port
      redis.del "#{address_with_port}:goes_as", "#{public_ip}:via"
    end


    def pick_for(options = {})
      key = Digest::SHA1.hexdigest(options[:context].to_json)

      if proxy = recently_used_proxy_for(key)
        return proxy
      end

      if proxy = new_association_for(key, options)
        return proxy
      end
      raise(NoProxyError, "No proxy registered at `#{redis.inspect}'")
    end

    private

    def new_proxy(options)
      key = options[:use_vpn] ? "hosts" : "no-vpn-hosts"
      if proxy = redis.rpoplpush(key, key)
        return URI.parse("http://#{proxy}")
      end
    end

    def new_association_for(key, options)
      if proxy = new_proxy(options)
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
