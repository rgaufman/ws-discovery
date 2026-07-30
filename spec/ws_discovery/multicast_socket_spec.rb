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

    it "adds 0.0.0.0 and 239.255.255.250 to the membership group" do
      expect(subject).to receive(:set_membership).with(
        IPAddr.new('239.255.255.250').hton + IPAddr.new('0.0.0.0').hton
      )
      subject.send(:setup_multicast_socket)
    end

    it "sets multicast TTL to 1" do
      expect(subject).to receive(:set_multicast_ttl).with(1)
      subject.send(:setup_multicast_socket)
    end

    it "sets TTL to 1" do
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
    it "passes '\\001' to the socket option call when param == :on" do
      expect(subject).to receive(:set_sock_opt).with(
        Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, "\001"
      )
      subject.send(:switch_multicast_loop, :on)
    end

    it "passes '\\001' to the socket option call when param == '\\001'" do
      expect(subject).to receive(:set_sock_opt).with(
        Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, "\001"
      )
      subject.send(:switch_multicast_loop, "\001")
    end

    it "passes '\\000' to the socket option call when param == :off" do
      expect(subject).to receive(:set_sock_opt).with(
        Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, "\000"
      )
      subject.send(:switch_multicast_loop, :off)
    end

    it "passes '\\000' to the socket option call when param == '\\000'" do
      expect(subject).to receive(:set_sock_opt).with(
        Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, "\000"
      )
      subject.send(:switch_multicast_loop, "\000")
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
