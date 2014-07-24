

describe MT::Proxy do

  let(:cache) { MT::Proxy.redis.data }
  let(:namespace) { MT::Proxy.namespace }
  let(:hosts_cache) { cache["#{namespace}:no-vpn-hosts"] }

  describe ".register" do

    let(:proxy_address) { "127.0.0.2:3128" }
    let(:public_address) { "0.0.1.1" }

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
      cache["#{namespace}:no-vpn-hosts"] << proxy_address
      MT::Proxy.register proxy_address, public_address
      expect(hosts_cache).to include(proxy_address)

      host_count = hosts_cache.select{|ip| ip == proxy_address }.count
      expect(host_count).to eq(1)
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


  before { register_first_proxy }

  describe ".pick" do

    its(:pick) { should be_an URI }

    it "should shuffle the list" do

      register_second_proxy
      expect(subject.pick).not_to eq(subject.pick)

    end

    it "should raise an error if no proxy is available" do

      unregister_first_proxy
      expect{subject.pick}.to raise_error(MT::Proxy::NoProxyError)

    end

  end


  describe ".pick_for(something)" do

    it "should return an URI" do
      expect(subject.pick_for(:context => 'something')).to be_an URI
    end

    it "should raise an error if no proxy is available" do

      unregister_first_proxy
      expect{subject.pick_for(:context => 'something')}.to raise_error(MT::Proxy::NoProxyError)

    end


    context "preserving the outgoing ip addres" do

      let(:context) { "a list of arguments that are not nil. may be anything that is serializable" }

      before { register_second_proxy }

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

end



