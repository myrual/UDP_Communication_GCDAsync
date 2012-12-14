UDP_Communication_GCDAsync
==========================

An UDP communication tool based on GCDAsync lib
### Help to finish following task:   ###
1. send unicast udp package to an destination and expect a reply packet.  
2. send multicast udp package to find some object and collect result.  \

### known issue ###
In listenning multicast mode, cocoaAsync lib will parse incoming IPV4 data packet address to IPV6 format    
### Solution ###
Check incoming package address length, return NO when address length does not match IPV4.