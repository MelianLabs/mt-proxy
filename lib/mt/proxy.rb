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

    #this is the default namespace
    mattr_accessor :namespace
    self.namespace = "proxy"

    #the default association time for a proxy
    mattr_accessor :association_ttl
    self.association_ttl = 3.minutes

    mattr_accessor :check_interval
    self.check_interval = 10.seconds

    #the current proxy group
    mattr_accessor :pool
    self.pool = "default-pool"

  #the current proxy group
    mattr_accessor :default_pool
    self.default_pool = pool

    mattr_accessor :max_retrys
    self.max_retrys = 5
    @redis_uri = "redis://localhost"

    # It sets the redis registry
    # connection_or_string can be a Redis instance or a redis uri
    #
    #  MT::Proxy.redis = Redis.new("redis://localhost")
    #  MT::Proxy.redis = "redis://localhost"
    #
    def redis=(connection_or_string)
      if connection_or_string.is_a? String
        @redis_uri  = connection_or_string
      else
        @redis = Redis::Namespace.new(namespace, :redis => connection_or_string)
      end
    end

    def redis # :nodoc:
      @redis ||= Redis::Namespace.new(namespace, :redis => Redis.new(url: @redis_uri || "redis://127.0.0.1" ))
    end

    # Picks a proxy from a pools of proxies.
    # Using the default pool MT::Proxy.default_pool
    #
    #   MT::Proxy.pick # => URI::HTTP
    #
    # Specifing a pool
    #
    #   MT::Proxy.pick pool: 'pool' # => URI::HTTP
    #
    # If no proxy is registered in the pool MT::Proxy::NoProxyErorr is raised
    def pick(options={})
      pool = options.fetch(:pool, default_pool)
      count = 0

      begin

        if proxy = redis.rpoplpush(pool, pool)
          return URI.parse("http://#{proxy}") if redis.get("#{proxy}:goes_as")
          redis.lrem pool, 0, proxy
        end

        raise(NoProxyError, "No proxy registered in pool `#{pool}'")

      rescue NoProxyError => e
        count +=1
        raise e if max_retrys < count
        retry
      end

    end

    #
    # Picks a proxy from a pool of proxies taking in consideration a context.
    # For successive invocations of this method if the context is the same with a previous invocation the same proxy will be returned.
    #
    # MT::Proxy.pick_for context: { username: 'some user', password: 'some password hash' } # => URI::HTTP
    #
    # the context option can be any object that is serializable into json
    #
    # Picking a proxy from a specified pool
    #
    # MT::Proxy.pick_for pool: 'a given pool', context: { username: 'some user', password: 'some password hash' } # => URI::HTTP
    #
    # If no proxy is registered in the pool MT::Proxy::NoProxyErorr is raised
    def pick_for(options = {})
      key = Digest::SHA1.hexdigest(options[:context].to_json)

      if proxy = recently_used_proxy_for(key)
        return proxy
      end

      new_association_for(key, options)
    end

    def limits(pool = nil)
      pool ||= self.pool
      limits = {}
      keys = redis.keys("limits:#{pool}:*")
      unless keys.empty?
        keys.zip(redis.mget(*keys)).each_with_object(limits) do |(key, limit), limits|
          key =~ /limits:([^:]+):(.*)/
          host = $2
          limits[host] = limit.to_i
        end
      end
      limits
    end

    #sets a limit for a given hostname
    #
    # MT::Proxy.set_limit "yahoo.com", 90
    #
    #only 90 proxy requests for yahoo.com after that a restart is triggered
    def set_limit(hostname, requests ,pool = nil)
      pool ||= self.pool
      redis.set "limits:#{pool}:#{hostname}", requests
    end

    #removes a limit for a given hostname
    # MT::Proxy.unset_limit "yahoo.com", 90
    def unset_limit(hostname, pool = nil)
      pool ||= self.pool
      redis.del "limits:#{pool}:#{hostname}"
    end

    #gets the limit for a given hostname
    #
    #  MT::Proxy.set_limit "yahoo.com", 90
    #  MT::Proxy.limit "yahoo.com" => 90
    #
    def limit(hostname, pool = nil)
      pool ||= self.pool
      limit = redis.get("limits:#{pool}:#{hostname}").to_i
      limit = 1.0 /0 if limit == 0 # Infinity
      limit
    end

    # Registers a proxy
    def register(address_with_port, public_ip)
      renew(address_with_port, public_ip)
      redis.lrem(pool, 0, address_with_port)
      redis.lpush(pool, address_with_port)
      guard_time = (check_interval * 3).round
      redis.setex("pools:#{pool}", guard_time, pool )
      redis.set("#{address_with_port}:registered_at", Time.now.to_i)
    end

    # Renew a proxy
    # This method also sets an expiration time so if no renewal is made in until the expiration deadline the proxy is removed from the pool
    def renew(address_with_port, public_ip)
      guard_time = (check_interval * 3).round
      redis.setex("#{address_with_port}:goes_as", guard_time, public_ip)
      redis.setex("pools:#{pool}", guard_time, pool )
      redis.setex("#{public_ip}:via", guard_time, address_with_port)
    end

    # Unregisters a proxy from a pool
    def unregister(address_with_port, public_ip)
      redis.lrem pool, 0, address_with_port
      redis.del "#{address_with_port}:goes_as", "#{public_ip}:via"
    end

    private


    def new_association_for(key, options) # :nodoc:
      if proxy = pick(options)
        public_ip = redis.get("#{proxy.host}:#{proxy.port}:goes_as")
        redis.setex("#{key}:via", association_ttl, public_ip)
        proxy
      end
    end


    def recently_used_proxy_for(key) # :nodoc:

      if public_ip = redis.get("#{key}:via") and proxy = redis.get("#{public_ip}:via")
        return URI.parse("http://#{proxy}")
      end

    end

  end
end
