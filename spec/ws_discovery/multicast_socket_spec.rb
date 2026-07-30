require 'spec_helper'
require 'ws_discovery/multicast_socket'

# Replaces multicast_connection_spec.rb. Same socket options, asserted against the
# real UDPSocket the class now owns instead of against EventMachine's set_sock_opt.
# The old #peer_info examples are gone with the method: recvfrom hands back the
# sender, so there is no sockaddr to unpack by hand any more (and the example that
# checked the port was a Fixnum had been failing since Ruby 3 removed the constant).
describe WSDiscovery::MulticastSocket do
  subject { WSDiscovery::MulticastSocket.new(1) }

  after { subject.close }

  describe "#initialize" do
    it "binds a UDP socket to an ephemeral port on 0.0.0.0" do
      address = subject.socket.local_address

      expect(address.ip_address).to eql '0.0.0.0'
      expect(address.ip_port).to be > 0
    end
  end

  describe "#setup_multicast_socket" do
    before do
      allow_any_instance_of(WSDiscovery::MulticastSocket).to receive(:set_membership)
      allow_any_instance_of(WSDiscovery::MulticastSocket).to receive(:switch_multicast_loop)
      allow_any_instance_of(WSDiscovery::MulticastSocket).to receive(:set_multicast_ttl)
      allow_any_instance_of(WSDiscovery::MulticastSocket).to receive(:set_ttl)
    end

    it "joins the group on every interface and sets both TTLs to the given value" do
      expect(subject).to receive(:set_membership).with(
        IPAddr.new('239.255.255.250').hton + IPAddr.new('0.0.0.0').hton
      )
      expect(subject).to receive(:set_multicast_ttl).with(1)
      expect(subject).to receive(:set_ttl).with(1)

      subject.send(:setup_multicast_socket)
    end

    context "ENV['RUBY_TESTING_ENV'] != testing" do
      after { ENV['RUBY_TESTING_ENV'] = "testing" }

      it "turns multicast loop off" do
        ENV['RUBY_TESTING_ENV'] = "development"
        expect(subject).to receive(:switch_multicast_loop).with(:off)
        subject.send(:setup_multicast_socket)
      end
    end
  end

  describe "#switch_multicast_loop" do
    # Both spellings of each state are accepted (the symbol, and the raw byte the option
    # takes), so all four map to one of two bytes.
    { :on => "\001", "\001" => "\001", :off => "\000", "\000" => "\000" }.each do |param, byte|
      it "passes #{byte.inspect} to setsockopt when param == #{param.inspect}" do
        expect(subject.socket).to receive(:setsockopt).with(
          Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, byte
        )
        subject.send(:switch_multicast_loop, param)
      end
    end

    it "raises when not :on, :off, '\\000', or '\\001'" do
      expect { subject.send(:switch_multicast_loop, 12312312) }.
        to raise_error(WSDiscovery::Error)
    end
  end

  describe "#close" do
    it "closes the socket, and tolerates being called twice" do
      subject.close
      expect(subject.socket).to be_closed

      expect { subject.close }.to_not raise_error
    end
  end
end
