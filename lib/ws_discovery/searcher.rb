require_relative 'multicast_socket'
require_relative 'response'
require 'semantic_logger'
require 'builder'
require 'securerandom'

class WSDiscovery::Searcher < WSDiscovery::MulticastSocket
  include SemanticLogger::Loggable

  # Largest payload a UDP datagram can carry (65535 less the 8-byte UDP and 20-byte
  # IP headers). ProbeMatches are far smaller, but reading the maximum means a
  # chatty device's response can never be silently truncated.
  MAX_DATAGRAM_SIZE = 65_507

  # @param [Hash] options The options for the probe.
  # @option options [Hash<String>] :env_namespaces Additional envelope namespaces.
  # @option options [Hash<String>] :type_attributes Type attributes.
  # @option options [String] :types Types.
  # @option options [Hash<String>] :scope_attributes Scope attributes.
  # @option options [String] :scopes Scopes.
  # @option options [Integer] :ttl TTL for the probe.
  def initialize(options={})
    options[:ttl] ||= TTL

    @search = probe(options)

    super options[:ttl]
  end

  # Sends the probe that was built during init.  Logs what was sent if the
  # send was successful.
  #
  # Was #post_init, which EventMachine called for us once the socket was up.
  #
  # @return [Integer] Bytes sent.
  def send_probe
    bytes = socket.send(@search, 0, MULTICAST_IP, MULTICAST_PORT)
    logger.info("Sent datagram search:\n#{@search}") if bytes > 0

    bytes
  end

  # Reads ONE pending datagram and parses it into a WSDiscovery::Response, with the
  # sender's IP and port merged into the hash -- that source address is the
  # authoritative one for the device, more trustworthy than anything it advertises
  # inside the XML.
  #
  # Was #receive_data, which EventMachine called with the payload already read and
  # the peer resolved via #peer_info. recvfrom returns both, so the peer no longer
  # has to be unpacked out of a sockaddr by hand.
  #
  # The caller must establish that the socket is readable first (WSDiscovery.search
  # uses IO.select) -- with no reactor handing out readability callbacks, this
  # blocks until a datagram arrives.
  #
  # @return [WSDiscovery::Response] The parsed response.
  def receive_response
    data, sender = socket.recvfrom(MAX_DATAGRAM_SIZE)
    port, ip = sender[1], sender[3]

    logger.info "<#{self.class}> Response from #{ip}:#{port}:\n#{data}\n"
    parsed_response = parse(data)
    parsed_response.to_hash[:ip] = ip
    parsed_response.to_hash[:port] = port

    parsed_response
  end

  # Converts the headers to a set of key-value pairs.
  #
  # @param [String] data The data to convert.
  # @return [WSDiscovery::Response] The converted data.
  def parse(data)
    WSDiscovery::Response.new(data)
  end

  # Probe for target services supporting WS-Discovery.
  #
  # @param [Hash] options The options for the probe.
  # @option options [Hash<String>] :env_namespaces Additional envelope namespaces.
  # @option options [Hash<String>] :type_attributes Type attributes.
  # @option options [String] :types Types.
  # @option options [Hash<String>] :scope_attributes Scope attributes.
  # @option options [String] :scopes Scopes.
  # @return [String] Probe SOAP message.
  def probe(options={})
    namespaces = {
      'xmlns:a' => 'http://schemas.xmlsoap.org/ws/2004/08/addressing',
      'xmlns:d' => 'http://schemas.xmlsoap.org/ws/2005/04/discovery',
      'xmlns:s' => 'http://www.w3.org/2003/05/soap-envelope'
    }
    namespaces.merge! options[:env_namespaces] if options[:env_namespaces]

    Builder::XmlMarkup.new.s(:Envelope, namespaces) do |xml|
      xml.s(:Header) do |xml|
        xml.a(:Action, 'http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe')
        xml.a(:MessageID, "uuid:#{SecureRandom.uuid}")
        xml.a(:To, 'urn:schemas-xmlsoap-org:ws:2005:04:discovery')
      end

      xml.s(:Body) do |xml|
        xml.d(:Probe) do
          xml.d(:Types, options[:type_attributes], options[:types])
          xml.d(:Scopes, options[:scope_attributes], options[:scopes])
        end
      end
    end
  end
end
