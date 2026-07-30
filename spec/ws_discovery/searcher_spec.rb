require 'spec_helper'
require 'ws_discovery/searcher'

describe WSDiscovery::Searcher do
  # The MessageID is a fresh SecureRandom.uuid per probe, so it is stubbed to keep
  # the expected XML byte-exact. (This spec used to stub UUID.generate, which has
  # not existed since the uuid gem was dropped for SecureRandom -- every example in
  # here was erroring on `uninitialized constant UUID` before this rewrite.)
  before { allow(SecureRandom).to receive(:uuid).and_return('a-uuid') }

  subject { WSDiscovery::Searcher.new(ttl: 1) }

  after { subject.close }

  describe "#initialize" do
    it "does a #probe" do
      expect_any_instance_of(WSDiscovery::Searcher).to receive(:probe).and_return('<probe/>')
      subject
    end
  end

  describe "#send_probe" do
    it "sends the probe as a datagram over 239.255.255.250:3702" do
      expect(subject.socket).to receive(:send).
        with(instance_of(String), 0, '239.255.255.250', 3702).
        and_return 42

      expect(subject.send_probe).to eql 42
    end
  end

  describe "#receive_response" do
    # ["AF_INET", port, hostname, numeric_ip] -- what UDPSocket#recvfrom returns as
    # its second element. The numeric IP is the device's authoritative address.
    let(:sender) { ['AF_INET', 4567, 'device.local', '1.2.3.4'] }

    before do
      allow(subject.socket).to receive(:recvfrom).and_return([ProbeMatchFixture::XML, sender])
    end

    it "parses the datagram into a WSDiscovery::Response" do
      expect(subject).to receive(:parse).with(ProbeMatchFixture::XML).and_call_original

      response = subject.receive_response

      expect(response).to be_a WSDiscovery::Response
      expect(response.to_hash.dig(:probe_matches, :probe_match, :x_addrs)).
        to eql 'http://10.221.222.74/onvif/device_service'
    end

    it "records the sender's IP and port on the response" do
      hash = subject.receive_response.to_hash

      expect(hash[:ip]).to eql '1.2.3.4'
      expect(hash[:port]).to eql 4567
    end
  end

  describe "#parse" do
    it "turns probe matches into WSDiscovery::Responses" do
      result = subject.parse "<Envelope />"
      expect(result).to be_a WSDiscovery::Response
    end
  end

  describe "#probe" do
    it "builds the probe string using the given parameters" do
      expect(subject.probe(
        env_namespaces: { "xmlns:dn" => "http://www.onvif.org/ver10/network/wsdl" },
        types: "dn:NetworkVideoTransmitter")).to eql <<-PROBE.strip
<s:Envelope xmlns:a=\"http://schemas.xmlsoap.org/ws/2004/08/addressing\" xmlns:\
d=\"http://schemas.xmlsoap.org/ws/2005/04/discovery\" xmlns:s=\"http://www.w3.o\
rg/2003/05/soap-envelope\" xmlns:dn=\"http://www.onvif.org/ver10/network/wsdl\"\
><s:Header><a:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</a:A\
ction><a:MessageID>uuid:a-uuid</a:MessageID><a:To>urn:schemas-xmlsoap-org:ws:20\
05:04:discovery</a:To></s:Header><s:Body><d:Probe><d:Types>dn:NetworkVideoTrans\
mitter</d:Types><d:Scopes/></d:Probe></s:Body></s:Envelope>
      PROBE
    end
  end
end
