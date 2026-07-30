require_relative 'core_ext/socket_patch'
require_relative 'network_constants'
require_relative 'error'
require 'ipaddr'
require 'socket'

module WSDiscovery
  # A UDP socket configured for the WS-Discovery multicast group.
  #
  # This was an EventMachine::Connection subclass, which was the only reason this
  # gem depended on EventMachine at all. What goes on the wire is unchanged:
  # EventMachine's set_sock_opt was a thin wrapper over setsockopt(2), the socket
  # is still bound to an ephemeral port on 0.0.0.0 before the options are applied
  # (EM.open_datagram_socket bound first, then ran the handler's initialize), and
  # the option values are identical. Only the plumbing above it is stdlib now.
  class MulticastSocket
    include WSDiscovery::NetworkConstants

    # The bound UDP socket. Exposed so callers can IO.select on it -- with no
    # reactor to hand out readability callbacks, waiting is the caller's job.
    attr_reader :socket

    # @param [Integer] ttl The TTL value to use when opening the UDP socket
    #   required for WSDiscovery actions.
    def initialize(ttl = TTL)
      @ttl = ttl
      @socket = UDPSocket.new
      @socket.bind('0.0.0.0', 0)

      setup_multicast_socket
    end

    def close
      @socket.close unless @socket.closed?
    end

    private

    # Sets Socket options to allow for multicasting. If ENV["RUBY_TESTING_ENV"]
    # is equal to "testing", then it doesn't turn off multicast looping.
    def setup_multicast_socket
      set_membership(IPAddr.new(MULTICAST_IP).hton + IPAddr.new('0.0.0.0').hton)
      set_multicast_ttl(@ttl)
      set_ttl(@ttl)

      unless ENV['RUBY_TESTING_ENV'] == 'testing'
        switch_multicast_loop :off
      end
    end

    # @param [String] membership The network byte ordered String that represents
    #   the IP(s) that should join the membership group.
    def set_membership(membership)
      set_sock_opt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, membership)
    end

    # @param [Integer] ttl TTL to set IP_MULTICAST_TTL to.
    def set_multicast_ttl(ttl)
      set_sock_opt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_TTL, [ttl].pack('i'))
    end

    # @param [Integer] ttl TTL to set IP_TTL to.
    def set_ttl(ttl)
      set_sock_opt(Socket::IPPROTO_IP, Socket::IP_TTL, [ttl].pack('i'))
    end

    # @param [Symbol] on_off Turn on/off multicast looping. Supply :on or :off.
    # @raise [WSDiscovery::Error] If invalid option is given.
    def switch_multicast_loop(on_off)
      hex_value = case on_off
      when :on, "\001"
        "\001"
      when :off, "\000"
        "\000"
      else
        raise WSDiscovery::Error, "Can't switch IP_MULTICAST_LOOP to '#{on_off}'"
      end

      set_sock_opt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_LOOP, hex_value)
    end

    # Kept as its own method, with EventMachine's name and argument order, so the
    # option-setting methods above read exactly as they did under the reactor.
    def set_sock_opt(level, option, value)
      @socket.setsockopt(level, option, value)
    end
  end
end
