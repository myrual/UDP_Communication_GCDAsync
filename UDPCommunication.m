//
//  UDPCommunication.m
//
//  Created by myrual on 12-9-6.
//  BSD licesne
//

#import "UDPCommunication.h"
#import "GCDAsyncUdpSocket.h"

@implementation UDPCommunication

@synthesize myDestinationHost = _myDestinationHost;
@synthesize myDestinationPort = _myDestinationPort;
@synthesize WaitingRespose = _WaitingRespose;
@synthesize mysocket = _mysocket;
@synthesize myContent = _myContent;
@synthesize maxTimeout = _maxTimeout;
@synthesize resendInterval = _resendInterval;
@synthesize recvFilteBlock = _recvFilteBlock;
@synthesize SuccessBlock = _SuccessBlock;
@synthesize safeSucceeBlock = _safeSucceeBlock;
@synthesize TimeoutAction = _TimeoutAction;
@synthesize timeOutResult =_timeOutResult;
@synthesize  readTimer = _readTimer;
@synthesize resendTimer = _resendTimer;
@synthesize listenForever = _listenForever;
@synthesize inFiterBlock = _inFiterBlock;
@synthesize inSuccessBlock = _inSuccessBlock;



-(id) init{
    self = [super init];
    if (self) {
        GCDAsyncUdpSocket *socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        if (socket == nil) {
            return self;
        }
        NSError *err;
        [socket bindToPort:0 error:&err];
        _mysocket = socket;
        _timeOutResult = [[NSMutableArray alloc] init];
        _inFiterBlock = NO;
        _inSuccessBlock = NO;
    }
    return self;
}

-(id) initWithPort:(uint16_t)bind_port{
    self = [super init];
    if (self) {
        GCDAsyncUdpSocket *socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        if (socket == nil) {
            return self;
        }
        NSError *err = nil;
        _timeOutResult = [[NSMutableArray alloc] init];

        [socket bindToPort:bind_port error:&err];
        if (err == nil) {
            _mysocket = socket;
        }
        socket = nil;
    }
    return self;
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


-(void) stopUdpCommunication{
    [self.mysocket pauseReceiving];
    
    if (self.resendTimer) {
        dispatch_source_cancel(self.resendTimer);
        dispatch_release(self.resendTimer);
        self.resendTimer = nil;
    }
    if (self.readTimer) {
        dispatch_source_cancel(self.readTimer);
        dispatch_release(self.readTimer);
        self.readTimer =nil;
    }
    self.TimeoutAction = nil;
    self.SuccessBlock = nil;
    self.recvFilteBlock = nil;
    self.safeSucceeBlock = nil;
    

}

-(void)closeUDPSocket{
    [self stopUdpCommunication];
    [self.mysocket close];
    _mysocket = nil;
}

-(void) setupFlagForEachOperation{
    self.inSuccessBlock = NO;
    self.inFiterBlock = NO;
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
    [self setupFlagForEachOperation];
    self.timeOutResult =  [[NSMutableArray alloc] init];
	if (inputMaxTimeout >= 0.0 && inputresendInterval >= 0.0)
	{
        [self.mysocket setDelegate:self];
        [self.mysocket setReceiveFilter:recvBlk withQueue:dispatch_get_main_queue()];
        if (flag) {
            NSError *err = nil;
            [self.mysocket enableBroadcast:flag error:&err];
            if (err != nil) {
                NSLog(@"set broadcast error");
            }
        }
        self.myContent = Content;
        self.myDestinationHost = host;
        self.myDestinationPort = port;
        self.maxTimeout = inputMaxTimeout;
        self.resendInterval = inputresendInterval;
        self.SuccessBlock = Success;
        self.TimeoutAction = timeoutProcess;
        self.recvFilteBlock = recvBlk;
        
        
        _resendTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        
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
            if (self.readTimer) {
                dispatch_source_set_event_handler(self.readTimer, ^{
                    //if timeout, stop receiving
                    [self.mysocket pauseReceiving];
                    
                    if (self.resendTimer) {
                        dispatch_source_cancel(self.resendTimer);
                        dispatch_release(self.resendTimer);
                        self.resendTimer = nil;
                    }
                    if (self.readTimer)
                    {
                        dispatch_source_cancel(self.readTimer);
                        dispatch_release(self.readTimer);
                    }
                    self.readTimer =nil;
                    if (self.TimeoutAction) {
                        self.TimeoutAction(self.timeOutResult);
                    }
                });
            }
            else{
                NSLog(@"Bang, !!!! Failed to create timer");
            }

            
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

-(void) safeSendWithContent:(NSData *)Content
                 toHost:(NSString *)host
                 toPort:(NSInteger)port
            withTimeout:(NSTimeInterval)inputMaxTimeout
     withResendInterval:(NSTimeInterval)inputresendInterval
        enableBroadCast:(BOOL) flag
     receiveFilterBlock:(GCDAsyncUdpSocketReceiveFilterBlock)recvBlk
                Success:(SuccessBlkTypeSafer)Success
             TimeoutBlk:(TimeoutBlkType)timeoutProcess{
    [self setupFlagForEachOperation];
    self.timeOutResult =  [[NSMutableArray alloc] init];
	if (inputMaxTimeout >= 0.0 && inputresendInterval >= 0.0)
	{
        [self.mysocket setDelegate:self];
        [self.mysocket setReceiveFilter:recvBlk withQueue:dispatch_get_main_queue()];
        if (flag) {
            NSError *err = nil;
            [self.mysocket enableBroadcast:flag error:&err];
            if (err != nil) {
                NSLog(@"set broadcast error");
            }
        }
        self.myContent = Content;
        self.myDestinationHost = host;
        self.myDestinationPort = port;
        self.maxTimeout = inputMaxTimeout;
        self.resendInterval = inputresendInterval;
        self.safeSucceeBlock = Success;
        self.TimeoutAction = timeoutProcess;
        self.recvFilteBlock = recvBlk;
        self.SuccessBlock = nil;
        
        
        _resendTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        
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
            if (self.readTimer) {
                dispatch_source_set_event_handler(self.readTimer, ^{
                    //if timeout, stop receiving
                    [self.mysocket pauseReceiving];
                    
                    if (self.resendTimer) {
                        dispatch_source_cancel(self.resendTimer);
                        dispatch_release(self.resendTimer);
                        self.resendTimer = nil;
                    }
                    if (self.readTimer)
                    {
                        dispatch_source_cancel(self.readTimer);
                        dispatch_release(self.readTimer);
                    }
                    self.readTimer =nil;
                    if (self.TimeoutAction) {
                        self.TimeoutAction(self.timeOutResult);
                    }
                });
            }
            else{
                NSLog(@"Bang, !!!! Failed to create timer");
            }
            
            
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
    
    
    self.timeOutResult =  [[NSMutableArray alloc] init];
    [self setupFlagForEachOperation];
	if (inputMaxTimeout > 0)
	{
        [self.mysocket setDelegate:self];
        [self.mysocket setReceiveFilter:recvBlk withQueue:dispatch_get_main_queue()];
        self.maxTimeout = inputMaxTimeout;
        self.SuccessBlock = Success;
        self.TimeoutAction = timeoutProcess;
        self.recvFilteBlock = recvBlk;
        
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
            if (self.readTimer) {
                dispatch_source_set_event_handler(self.readTimer, ^{
                    //if timeout, stop receiving
                    [self.mysocket pauseReceiving];
                    dispatch_source_cancel(self.readTimer);
                    dispatch_release(self.readTimer);
                    self.readTimer =nil;
                    if (self.TimeoutAction) {
                        self.TimeoutAction(self.timeOutResult);
                    }

                });
            }else{
                NSLog(@"Failed to create Timer !!!!!!!!!!!!!!!!");
            }
            

            
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
    if (self.safeSucceeBlock == nil && self.SuccessBlock == nil) {
        NSNumber *peerPort = [NSNumber numberWithInteger:port];
        NSDictionary *filtedData = [NSDictionary dictionaryWithObjectsAndKeys:data, @"data", host, @"host", peerPort, @"port", nil];
        [self.timeOutResult addObject:filtedData];
    }
    else{
        [self.mysocket pauseReceiving];
        if (self.inSuccessBlock == NO) {
            self.inSuccessBlock = YES;
            if (self.resendTimer) {
                dispatch_source_cancel(self.resendTimer);
                dispatch_release(self.resendTimer);
                self.resendTimer = nil;
            }
            if(self.readTimer){
                dispatch_source_cancel(self.readTimer);
                dispatch_release(self.readTimer);
                self.readTimer = nil;
            }
            if (self.safeSucceeBlock) {
                BOOL result = self.safeSucceeBlock(data, host, port);
                if (result) {
                    ;
                }
            }else{
                if (self.SuccessBlock) {
                    self.SuccessBlock(data, host, port);
                }
            }
            self.inSuccessBlock = NO;
            if (self.listenForever == YES) {
                NSError *err = nil;
                [self.mysocket beginReceiving:&err];
            }
        }


    }
}

@end
