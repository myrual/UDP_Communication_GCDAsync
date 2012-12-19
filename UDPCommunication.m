//
//  UDPCommunication.m
//  anfang
//
//  Created by lilin on 12-9-6.
//  Copyright (c) 2012年 lilin. All rights reserved.
//

#import "UDPCommunication.h"
#import "GCDAsyncUdpSocket.h"

@implementation UDPCommunication

@synthesize myDestinationHost = _myDestinationHost;
@synthesize myDestinationPort = _myDestinationPort;
@synthesize StartTime = _StartTime;
@synthesize WaitingRespose = _WaitingRespose;
@synthesize mysocket = _mysocket;
@synthesize myContent = _myContent;
@synthesize maxTimeout = _maxTimeout;
@synthesize resendInterval = _resendInterval;
@synthesize recvFilteBlock = _recvFilteBlock;
@synthesize SuccessBlock = _SuccessBlock;
@synthesize TimeoutAction = _TimeoutAction;
@synthesize timeOutResult;
@synthesize  readTimer = _readTimer;
@synthesize resendTimer = _resendTimer;
@synthesize listenForever = _listenForever;

-(NSMutableArray *) timeOutResult{
    if (self.timeOutResult == nil) {
        self.timeOutResult = [[NSMutableArray alloc] init];
    }
    return self.timeOutResult;
}

-(id) init{
    id mm = [super init];
    if (mm) {
        GCDAsyncUdpSocket *socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        if (socket == nil) {
            return nil;
        }
        NSError *err;
        [socket bindToPort:0 error:&err];
        self.mysocket = socket;
    }
    return mm;
}

-(id) initWithPort:(uint16_t)bind_port{
    id mm = [super init];
    if (mm) {
        GCDAsyncUdpSocket *socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        if (socket == nil) {
            return nil;
        }
        NSError *err;
        [socket bindToPort:bind_port error:&err];
        self.mysocket = socket;
    }
    return mm;
}
-(id) initWithContent:(NSData *)Content
               toHost:(NSString *)host
               toPort:(NSInteger)port
          withTimeout:(NSTimeInterval)inputMaxTimeout
   withResendInterval:(NSTimeInterval)inputresendInterval
   receiveFilterBlock:(GCDAsyncUdpSocketReceiveFilterBlock)recvBlk
              Success:(SuccessBlkType)Success
           TimeoutBlk:(TimeoutBlkType)timeoutProcess{
    id myself = [self init];
    if (myself) {
        self.myContent = Content;
        self.myDestinationHost = host;
        self.myDestinationPort = port;
        self.maxTimeout = inputMaxTimeout;
        self.SuccessBlock = Success;
        self.TimeoutAction = timeoutProcess;
        self.recvFilteBlock = recvBlk;
    }
    return myself;
}

#define DEFAULT_TIMEOUT_SENDUDP 5
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
 //                     Success:nil
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
             TimeoutBlk:(TimeoutBlkType)timeoutProcess{

    
    
	if (inputMaxTimeout >= 0.0 && inputresendInterval >= 0.0)
	{
        [self.mysocket setDelegate:self];
        [self.mysocket setReceiveFilter:recvBlk withQueue:dispatch_get_main_queue()];
        if (flag) {
            NSError *err = nil;
            [self.mysocket enableBroadcast:flag error:&err];
        }
        self.myContent = Content;
        self.myDestinationHost = host;
        self.myDestinationPort = port;
        self.maxTimeout = inputMaxTimeout;
        self.resendInterval = inputresendInterval;
        self.SuccessBlock = Success;
        self.TimeoutAction = timeoutProcess;
        self.recvFilteBlock = recvBlk;
        
        self.StartTime = [[NSDate alloc] init];
        
        self.resendTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        
		dispatch_source_set_event_handler(self.resendTimer, ^{ @autoreleasepool {
            [self.mysocket sendData:self.myContent toHost:self.myDestinationHost port:self.myDestinationPort withTimeout:DEFAULT_TIMEOUT_SENDUDP tag:2];
		}});
		
#if NEEDS_DISPATCH_RETAIN_RELEASE
		dispatch_source_t theReadTimer = readTimer;
		dispatch_source_set_cancel_handler(readTimer, ^{
			LogVerbose(@"dispatch_release(readTimer)");
			dispatch_release(theReadTimer);
		});
#endif
		
		dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, 0);
		
		dispatch_source_set_timer(self.resendTimer, tt, self.resendInterval * NSEC_PER_SEC, 0);
        if (inputMaxTimeout >= 0.0)
        {

            self.readTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
            
            dispatch_source_set_event_handler(self.readTimer, ^{
                //if timeout, stop receiving
                [self.mysocket pauseReceiving];

                if (self.resendTimer) {
                    dispatch_source_cancel(self.resendTimer);
                    dispatch_release(self.resendTimer);
                    self.resendTimer = nil;
                }
                dispatch_source_cancel(self.readTimer);
                dispatch_release(self.readTimer);
                self.readTimer =nil;

            timeoutProcess(self.timeOutResult);
            });
            
#if NEEDS_DISPATCH_RETAIN_RELEASE
            dispatch_source_t theReadTimer = readTimer;
            dispatch_source_set_cancel_handler(readTimer, ^{
                LogVerbose(@"dispatch_release(readTimer)");
                dispatch_release(theReadTimer);
            });
#endif
            
            dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (self.maxTimeout * NSEC_PER_SEC));
            
            dispatch_source_set_timer(self.readTimer, tt, inputMaxTimeout * NSEC_PER_SEC, (inputMaxTimeout+1) * NSEC_PER_SEC);
        }
        //[self setupReadTimerWithTimeout:self.maxTimeout withDispatchQueue:nil];

        NSError *err = nil;
        [self.mysocket beginReceiving:&err];
        dispatch_resume(self.readTimer);
		dispatch_resume(self.resendTimer);
	}
}


#define DEFAULT_TIMEOUT_SENDUDP 5
/*  Following is an example
 [localTest listenningTimeOut:20
 receiveFilterBlock:^(NSData *data, NSData *address, id *context){
 NSLog(@"receive data %@ with address length %d from %@", data, [address length], address);
 if ([address length] == 16) {
 return YES;
 }
 else {
 return NO;
 }
 }
 Success:^(NSData *data, NSString *host, NSInteger port){
 NSLog(@"success with data %@ from %@ port%d", data, host, port);
 }
 TimeoutBlk:^(NSArray *result){
 NSLog(@"time out");
 for (NSDictionary *obj in result) {
 NSLog(@"%@", obj);
 }
 }];
 */
-(void) listenningTimeOut:(NSTimeInterval)inputMaxTimeout
     receiveFilterBlock:(GCDAsyncUdpSocketReceiveFilterBlock)recvBlk
                Success:(SuccessBlkType)Success
             TimeoutBlk:(TimeoutBlkType)timeoutProcess{
    
    
    
	if (inputMaxTimeout > 0)
	{
        [self.mysocket setDelegate:self];
        [self.mysocket setReceiveFilter:recvBlk withQueue:dispatch_get_main_queue()];
        self.maxTimeout = inputMaxTimeout;
        self.SuccessBlock = Success;
        self.TimeoutAction = timeoutProcess;
        self.recvFilteBlock = recvBlk;
        
        self.StartTime = [[NSDate alloc] init];
#if NEEDS_DISPATCH_RETAIN_RELEASE
		dispatch_source_t theReadTimer = readTimer;
		dispatch_source_set_cancel_handler(readTimer, ^{
			LogVerbose(@"dispatch_release(readTimer)");
			dispatch_release(theReadTimer);
		});
#endif
		
        if (inputMaxTimeout > 0)
        {
            
            self.readTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
            
            dispatch_source_set_event_handler(self.readTimer, ^{
                //if timeout, stop receiving
                [self.mysocket pauseReceiving];
                dispatch_source_cancel(self.readTimer);
                dispatch_release(self.readTimer);
                self.readTimer =nil;
                
                timeoutProcess(self.timeOutResult);
            });
            
#if NEEDS_DISPATCH_RETAIN_RELEASE
            dispatch_source_t theReadTimer = readTimer;
            dispatch_source_set_cancel_handler(readTimer, ^{
                LogVerbose(@"dispatch_release(readTimer)");
                dispatch_release(theReadTimer);
            });
#endif
            
            dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (self.maxTimeout * NSEC_PER_SEC));
            
            dispatch_source_set_timer(self.readTimer, tt, inputMaxTimeout * NSEC_PER_SEC, (inputMaxTimeout+1) * NSEC_PER_SEC);
        }
        //[self setupReadTimerWithTimeout:self.maxTimeout withDispatchQueue:nil];
        
        NSError *err = nil;
        [self.mysocket beginReceiving:&err];
        if (self.readTimer) {
            dispatch_resume(self.readTimer);
        }

	}
}

-(void) listenningForeverWithreceiveFilterBlock:(GCDAsyncUdpSocketReceiveFilterBlock)recvBlk
                  Success:(SuccessBlkType)Success{
    [self.mysocket setDelegate:self];
    [self.mysocket setReceiveFilter:recvBlk withQueue:dispatch_get_main_queue()];
    self.SuccessBlock = Success;
    self.recvFilteBlock = recvBlk;
    self.listenForever = YES;
    
    self.StartTime = [[NSDate alloc] init];
#if NEEDS_DISPATCH_RETAIN_RELEASE
    dispatch_source_t theReadTimer = readTimer;
    dispatch_source_set_cancel_handler(readTimer, ^{
        LogVerbose(@"dispatch_release(readTimer)");
        dispatch_release(theReadTimer);
    });
#endif
    
    NSError *err = nil;
    [self.mysocket beginReceiving:&err];
}

-(void) stopListeningForEver{
    self.listenForever = NO;
    [self.mysocket pauseReceiving];
}
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
	// You could add checks here
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
	// You could add checks here
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext
{
    NSString *host = nil;
    uint16_t port = 0;
    [GCDAsyncUdpSocket getHost:&host port:&port fromAddress:address];
    //if successBlock is nil, that means get all data after timeout
    if (self.SuccessBlock == nil) {
        NSNumber *peerPort = [NSNumber numberWithInteger:port];
        NSDictionary *filtedData = [NSDictionary dictionaryWithObjectsAndKeys:data, @"data", host, @"host", peerPort, @"port", nil];
        [self.timeOutResult addObject:filtedData];
    }
    else{

        if (self.resendTimer) {
            dispatch_source_cancel(self.resendTimer);
            dispatch_release(self.resendTimer);
            self.resendTimer = NULL;
        }
        if(self.readTimer){
            dispatch_source_cancel(self.readTimer);
            dispatch_release(self.readTimer);
            self.readTimer = NULL;
        }
        [self.mysocket pauseReceiving];
        self.SuccessBlock(data, host, port);
        if (self.listenForever == YES) {
            NSError *err = nil;
            [self.mysocket beginReceiving:&err];
        }
    }
}

@end
