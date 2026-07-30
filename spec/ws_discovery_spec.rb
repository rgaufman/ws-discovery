require 'spec_helper'
require 'ws_discovery'

describe WSDiscovery do
  subject { WSDiscovery }

  describe '.search' do
    let(:searcher) do
      instance_double WSDiscovery::Searcher, socket: socket, send_probe: 100, close: nil
    end
    let(:socket) { instance_double UDPSocket }

    before { allow(WSDiscovery::Searcher).to receive(:new).and_return(searcher) }

    it "sends one probe and collects every response that arrives in the window" do
      responses = %w[one two]
      allow(IO).to receive(:select).and_return([socket], [socket], nil)
      allow(searcher).to receive(:receive_response).and_return(*responses)

      expect(searcher).to receive(:send_probe).once

      expect(subject.search).to eql responses
    end

    it "returns an empty Array when nothing answers" do
      allow(IO).to receive(:select).and_return(nil)

      expect(subject.search).to eql []
    end

    # The window is the whole point of the call: a probe has no "last" response, so
    # the only thing that ends the search is the deadline.
    it "waits response_wait_time for responses" do
      allow(IO).to receive(:select) do |_read, _write, _error, timeout|
        expect(timeout).to be <= 0.25
        expect(timeout).to be > 0
        nil
      end

      subject.search(response_wait_time: 0.25)
    end

    # Without this, every scan on a long-lived process leaks a file descriptor --
    # tetherbox re-scans continuously.
    it "closes the socket even when a response blows up" do
      allow(IO).to receive(:select).and_return([socket])
      allow(searcher).to receive(:receive_response).and_raise(WSDiscovery::Error, 'bad xml')

      expect(searcher).to receive(:close)
      expect { subject.search }.to raise_error(WSDiscovery::Error)
    end
  end
end
