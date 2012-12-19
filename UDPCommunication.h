//
//  UDPCommunication.h
//  anfang
//
//  Created by lilin on 12-9-6.
//  Copyright (c) 2012年 lilin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncUdpSocket.h"

@interface UDPCommunication : NSObject
typedef void (^TimeoutBlkType)(NSArray *);
typedef void (^SuccessBlkType)(NSData*, NSString *, NSInteger port);
@property (nonatomic, strong) NSString * myDestinationHost;
@property (nonatomic) NSInteger myDestinationPort;
@property (nonatomic) BOOL WaitingRespose;
@property (nonatomic) NSDate * StartTime;
@property (nonatomic, strong) GCDAsyncUdpSocket *mysocket;
@property (nonatomic) NSTimeInterval maxTimeout;
@property (nonatomic) NSTimeInterval resendInterval;
@property (nonatomic, strong) NSData *myContent;
@property (nonatomic, strong) GCDAsyncUdpSocketReceiveFilterBlock recvFilteBlock;
@property (nonatomic, strong) TimeoutBlkType TimeoutAction;
@property (nonatomic, strong) SuccessBlkType SuccessBlock;
@property (nonatomic, strong) NSMutableArray *timeOutResult;
@property (nonatomic) 	dispatch_source_t readTimer;
@property (nonatomic) 	dispatch_source_t resendTimer;
@property (nonatomic)   BOOL listenForever;
//prepare follow:
//content, destination, max timeout
//block to check the incoming UDP data is expected data
//block to run when check incoming data return true
//block to run when time out happen

-(id) initWithPort:(uint16_t)bind_port;
/*  Following is an example
 UDPCommunication *udpComm = [[UDPCommunication alloc] init];
 NSData *broadcast = [[NSData alloc] initWithBytes:"abcdefg" length:3];
 [udpComm SendWithContent:broadcast
                   toHost:@"255.255.255.255"
                   toPort:10240
              withTimeout:5
       withResendInterval:0.2
          enableBroadCast:YES
       receiveFilterBlock:^(NSData *data, NSData *address, id *context){
        NSLog(@"receive filter");
        return YES;
        }
                  Success:^(NSData *data, NSString *host, NSInteger port){
        NSLog(@"success with data %@ from %@ port%d", data, host, port);
        }
               TimeoutBlk:^(NSArray *result){
        NSLog(@"timeout with %@", result);
        }
        ];
 */
-(void) SendWithContent:(NSData *)Content
                 toHost:(NSString *)host
                 toPort:(NSInteger)port
            withTimeout:(NSTimeInterval)inputMaxTimeout
     withResendInterval:(NSTimeInterval)inputresendInterval
        enableBroadCast:(BOOL) flag
     receiveFilterBlock:(GCDAsyncUdpSocketReceiveFilterBlock)recvBlk
                Success:(SuccessBlkType)Success
             TimeoutBlk:(TimeoutBlkType)timeoutProcess;



-(void) listenningTimeOut:(NSTimeInterval)inputMaxTimeout
receiveFilterBlock:(GCDAsyncUdpSocketReceiveFilterBlock)recvBlk
           Success:(SuccessBlkType)Success
        TimeoutBlk:(TimeoutBlkType)timeoutProcess;
-(void) listenningForeverWithreceiveFilterBlock:(GCDAsyncUdpSocketReceiveFilterBlock)recvBlk
                                        Success:(SuccessBlkType)Success;

-(void) stopListeningForEver;
@end
