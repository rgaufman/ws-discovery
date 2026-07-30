# A real ProbeMatches response, captured from a Pelco NET5404T encoder. Shared by
# response_spec (which asserts how it parses) and searcher_spec (which asserts what
# the searcher does with a datagram), so the two cannot drift onto different ideas
# of what a device actually sends back.
module ProbeMatchFixture
  XML = <<-PROBE
      <s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"
        xmlns:a="http://schemas.xmlsoap.org/ws/2004/08/addressing"
        xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery">
        <s:Header>
          <a:To>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</a:To>
          <a:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/ProbeMatches</a:Action>
          <a:MessageID>urn:uuid:18523f7e-7a54-d92d-a18d-e7165bec8e7e</a:MessageID>
          <a:RelatesTo>uuid:7dbdede0-0f2b-0130-5861-002564b29b24</a:RelatesTo>
          <d:AppSequence MessageNumber="42" InstanceId="2"/>
        </s:Header>
        <s:Body>
          <d:ProbeMatches>
            <d:ProbeMatch>
              <a:EndpointReference>
                <a:Address>urn:uuid:0b679890-fc54-14ba-d428-f73b3e7c2400</a:Address>
              </a:EndpointReference>
              <d:Types xmlns:dn="http://www.onvif.org/ver10/network/wsdl">dn:NetworkVideoTransmitter</d:Types>
              <d:Scopes>onvif://www.onvif.org/Profile/Streaming onvif://www.onvif.org/hardware/NET5404T onvif://www.onvif.org/type/ptz onvif://www.onvif.org/type/video_encoder onvif://www.onvif.org/location/country/usa onvif://www.onvif.org/name/NET5404T-ABEPZH7</d:Scopes>
              <d:XAddrs>http://10.221.222.74/onvif/device_service</d:XAddrs>
              <d:MetadataVersion>1</d:MetadataVersion>
            </d:ProbeMatch>
          </d:ProbeMatches>
        </s:Body>
      </s:Envelope>
    PROBE
end
