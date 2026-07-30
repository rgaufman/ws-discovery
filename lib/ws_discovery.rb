require_relative 'ws_discovery/core_ext/socket_patch'

require_relative 'ws_discovery/error'
require_relative 'ws_discovery/network_constants'
require_relative 'ws_discovery/searcher'

module WSDiscovery
  include NetworkConstants

  DEFAULT_WAIT_TIME = 5

  # Opens a UDP socket on 0.0.0.0, on an ephemeral port, has WSDiscovery::Searcher
  # build and send the search request, then receives the responses.  The search
  # will stop after +response_wait_time+.
  #
  # This used to run an EventMachine reactor for the duration of the search, which
  # was this gem's only reason to depend on EventMachine. A probe is one datagram
  # out and N datagrams back inside a fixed window, so an IO.select loop expresses
  # it directly -- and, unlike the reactor, it does not install process-wide INT /
  # TERM / HUP handlers. The old code needed those to stop the reactor, which meant
  # every search silently replaced its host application's signal handlers and never
  # put them back.
  #
  # @param [Hash] options The options for the probe.
  # @option options [Hash<String>] :env_namespaces Additional envelope namespaces.
  # @option options [Hash<String>] :type_attributes Type attributes.
  # @option options [String] :types Types.
  # @option options [Hash<String>] :scope_attributes Scope attributes.
  # @option options [String] :scopes Scopes.
  # @option options [Numeric] :response_wait_time Seconds to collect responses for.
  # @return [Array<WSDiscovery::Response>] The probe responses, in arrival order.
  def self.search(options={})
    response_wait_time = options[:response_wait_time] || DEFAULT_WAIT_TIME
    responses = []

    searcher = WSDiscovery::Searcher.new(options)
    searcher.send_probe

    # Monotonic, so an NTP correction mid-search cannot stretch or collapse the
    # window. The deadline is absolute rather than per-datagram, so a slow device
    # still gets counted as long as it answers inside the window.
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + response_wait_time

    loop do
      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      break if remaining <= 0
      break unless IO.select([searcher.socket], nil, nil, remaining) # nil == window expired

      responses << searcher.receive_response
    end

    responses
  ensure
    searcher&.close
  end
end
