To:SIP/2.0 180 Ringing
Via: SIP/2.0/TCP a.example.com
 ;branch=z9hG4bKfolded
Via: SIP/2.0/TCP b.example.com;branch=z9hG4bKsecond
To: <sip:bob@biloxi.example.com>
 ;tag=xyz
From: <sip:alice@atlanta.example.com>;tag=1
Call-ID: folded
  call@example.com
CSeq: 1 INVITE
Record-Route: <sip:p1.example.com;lr>, <sip:p2.example.com;lr>
Record-Route: <sip:p3.example.com;lr>

