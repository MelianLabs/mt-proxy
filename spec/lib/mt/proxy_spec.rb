

describe MT::Proxy do

  let(:cache) { MT::Proxy.redis.data }
  let(:namespace) { MT::Proxy.namespace }
  let(:hosts_cache) { cache["#{namespace}:#{MT::Proxy.pool}"] }

  let(:proxy) { unused_proxy }
  before { register_proxy proxy }

  describe ".register" do

    let(:other_proxy) { unused_proxy }
    let(:proxy_address) { other_proxy[:proxy_address]}
    let(:public_address) { other_proxy[:public_address]}


    it "should register the proxy_address->public_address mapping" do
      expect{ MT::Proxy.register proxy_address, public_address  }.to change{ cache["#{namespace}:#{proxy_address}:goes_as"] }.to(public_address)
    end

    it "should register the public_address->proxy_address mapping" do
      expect{ MT::Proxy.register proxy_address, public_address  }.to change{ cache["#{namespace}:#{public_address}:via"] }.to(proxy_address)
    end

    it "should register the proxy_address in the hosts list" do
      expect{ MT::Proxy.register proxy_address, public_address  }.to change(hosts_cache,:count).by(1)
      expect(hosts_cache).to include(proxy_address)
    end

    it "should remove the garbage from the list" do
      cache["#{namespace}:#{MT::Proxy.pool}"] << proxy_address
      register_proxy other_proxy
      expect(hosts_cache).to include(proxy_address)

      host_count = hosts_cache.select{|ip| ip == proxy_address }.count
      expect(host_count).to eq(1)
    end

    it "should set the a registration date" do
      Timecop.freeze
      time = Time.now.to_i.to_s
      expect{ MT::Proxy.register proxy_address, public_address  }.to change{ cache["#{namespace}:#{proxy_address}:registered_at"] }.to(time)
    end

  end

  describe ".unregister" do

    let(:proxy_address) { "127.0.0.2:3128" }
    let(:public_address) { "0.0.1.1" }
    before { MT::Proxy.register proxy_address, public_address }

    it "should remove the proxy_address->public_address mapping" do
      expect{ MT::Proxy.unregister proxy_address, public_address  }.to change{ cache["#{namespace}:#{proxy_address}:goes_as"] }.to(nil)
    end

    it "should remove the public_address->proxy_address mapping" do
      expect{ MT::Proxy.unregister proxy_address, public_address  }.to change{ cache["#{namespace}:#{public_address}:via"] }.to(nil)
    end

    it "should remove the proxy_address in the hosts list" do
      expect{ MT::Proxy.unregister proxy_address, public_address  }.to change(hosts_cache,:count).by(-1)
      expect(hosts_cache).not_to include(proxy_address)
    end

  end

  describe ".pick" do

    its(:pick) { should be_an URI }

    it "should shuffle the list" do

      register_proxy unused_proxy
      expect(subject.pick).not_to eq(subject.pick)

    end

    it "should raise an error if no proxy is available" do

      unregister_proxy proxy
      expect{subject.pick}.to raise_error(MT::Proxy::NoProxyError)

    end

    context "from a pool" do

      let(:pool) { "some other pool name"}
      let(:other_proxy) { unused_proxy.merge(pool: pool) }
      let(:pool_hosts_cache) { cache["#{namespace}:#{pool}"] }
      before { register_proxy  other_proxy }

      focus "should not pick a proxy from other pool" do
        proxy = subject.pick pool: pool
        expect(hosts_cache).not_to include("#{proxy.host}:#{proxy.port}")
        expect(pool_hosts_cache).to include("#{proxy.host}:#{proxy.port}")
      end

    end


  end


  describe ".pick_for(something)" do

    it "should return an URI" do
      expect(subject.pick_for(:context => 'something')).to be_an URI
    end

    it "should raise an error if no proxy is available" do

      unregister_proxy proxy
      expect{subject.pick_for(:context => 'something')}.to raise_error(MT::Proxy::NoProxyError)

    end

    context "from a pool" do

      let(:pool) { "some other pool name"}
      let(:other_proxy) { unused_proxy.merge(pool: pool) }
      let(:pool_hosts_cache) { cache["#{namespace}:#{pool}"] }
      before { register_proxy  other_proxy }

      focus "should not pick a proxy from other pool" do
        proxy = subject.pick_for pool: pool
        expect(hosts_cache).not_to include("#{proxy.host}:#{proxy.port}")
        expect(pool_hosts_cache).to include("#{proxy.host}:#{proxy.port}")
      end

    end



    context "preserving the outgoing ip addres" do

      before { MT::Proxy.check_interval = 10.minutes }
      let(:context) { "a list of arguments that are not nil. may be anything that is serializable" }

      before { register_proxy unused_proxy }

      it "should get the same proxy each time I'm using the same context" do
        expect(subject.pick_for(:context => context)).to eq(subject.pick_for(:context => context))
      end

      it "should not get the same proxy if the association_ttl has expired" do
        proxy = subject.pick_for(:context => context)
        Timecop.travel MT::Proxy.association_ttl.from_now + 1.second
        expect(proxy).not_to eq(subject.pick_for(:context => context))

      end

    end

  end

  describe "limits"  do

    it "should set a limit" do
      expect { MT::Proxy.set_limit  "example.host", 90 }.to change{ cache["#{namespace}:limits:#{MT::Proxy.pool}:example.host"] }.to("90")
    end

    it "should unset a limit" do
      MT::Proxy.set_limit  "example.host", 90
      expect { MT::Proxy.unset_limit  "example.host" }.to change{ cache["#{namespace}:limits:#{MT::Proxy.pool}:example.host"] }.to(nil)
    end

    it "should get the list of limits" do
      MT::Proxy.set_limit  "example.host", 90
      expect(MT::Proxy.limits).to include "example.host" => 90
    end

    it "should get the limit" do
      MT::Proxy.set_limit  "example.host", 90
      expect(MT::Proxy.limit  "example.host").to eq(90)
    end

  end

end



