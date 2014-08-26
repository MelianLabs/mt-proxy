# MT::Proxy

  MyTime proxy checker and chooser

## Installation

Add this line to your application's Gemfile:

    gem 'mt-proxy', github: 'vvlad/mt-proxy'

And then execute:

    $ bundle

## Configuration
  You need to provide a redis database


    MT::Proxy.redis = "redis://127.0.0.1/2"

    MT::Proxy.redis = Redis.new(url: "redis://127.0.0.1/2")


## Usage

### Picking up a proxy

    MT::Proxy.pick pool: 'default'
    => returns a URI of a proxy from in the given pool

### Picking up a proxy with persitance
eq a previous request has been made and we want to get the same public ip

    MT::Proxy.pick_for pool: 'default', context: 'bah blah blah'
    => returns a URI of a proxy from in the given pool

the context can be any object that can be serialized in a json or a unique hash key


### Setting up limits

    MT::Proxy.set_limit "yahoo.com", 90

The proxy will forward 90 request to the given domain after that will trigger a restart

    MT::Proxy.unset_limit "yahoo.com"

removes the  limit for yahoo.com

    MT::Proxy.limits

returns a hash with the current known limits { "hostname" => limit }

    MT::Proxy.limit "yahoo.com"

returns the limit for the given hostname

