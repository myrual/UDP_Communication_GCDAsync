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


### example ###

```
UDPCommunication *udpComm = [[UDPCommunication alloc] init];
NSData *broadcast = [[NSData alloc] initWithBytes:"abcdefg" length:3];
[udpComm SendWithContent:broadcast
                  toHost:@"255.255.255.255"
                  toPort:12345
             withTimeout:10
      withResendInterval:0.1
         enableBroadCast:YES
      receiveFilterBlock:^(NSData *data, NSData *address, id *context){
          NSLog(@"receive filter");
          return YES;
      }
                 Success:^(NSData *data, NSString *host, NSInteger port){
                     NSLog(@"success with data %@ from %@ port%d", data, host, port);
                 }
 //                     Success:nil
              TimeoutBlk:^(NSArray *result){
                  NSLog(@"timeout with %@", result);
              }
 ];
 
```
``` 
-(void) listenningTimeOut:(NSTimeInterval)inputMaxTimeout
receiveFilterBlock:(GCDAsyncUdpSocketReceiveFilterBlock)recvBlk
           Success:(SuccessBlkType)Success
        TimeoutBlk:(TimeoutBlkType)timeoutProcess;
        
```

```
-(void) listenningForeverWithreceiveFilterBlock:(GCDAsyncUdpSocketReceiveFilterBlock)recvBlk
                                        Success:(SuccessBlkType)Success;
                                        
```
 
 
 