//
//  OpentokPlugin.m
//
//  Copyright (c) 2012 TokBox. All rights reserved.
//  Please see the LICENSE included with this distribution for details.
//

#import "OpenTokPlugin.h"

@implementation OpenTokPlugin{
    OTSession* _session;
    OTPublisher* _publisher;
    OTSubscriber* _subscriber;
    NSMutableDictionary *subscriberDictionary;
    NSMutableDictionary *connectionDictionary;
    NSMutableDictionary *streamDictionary;
    NSMutableDictionary *callbackList;
    NSString *apiKey;
    NSString *sessionId;
    NSMutableDictionary *observersDictionary;
}

@synthesize exceptionId;

#pragma mark -
#pragma mark Cordova Methods
-(void) pluginInitialize{
    // Make the web view transparent.
    [self.webView setOpaque:false];
    [self.webView setBackgroundColor:UIColor.clearColor];

    callbackList = [[NSMutableDictionary alloc] init];
}
- (void)addEvent:(CDVInvokedUrlCommand*)command{
    NSString* event = [command.arguments objectAtIndex:0];
    [callbackList setObject:command.callbackId forKey: event];
}


#pragma mark -
#pragma mark Cordova JS - iOS bindings
#pragma mark TB Methods
/*** TB Methods
 ****/
// Called by TB.addEventListener('exception', fun...)
-(void)exceptionHandler:(CDVInvokedUrlCommand*)command{
    self.exceptionId = command.callbackId;
}
-(void)logOT:(NSString*)connectionId{
    NSURL *url = [NSURL URLWithString:@"https://hlg.tokbox.com/prod/logging/ClientEvent"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPMethod = @"POST";

    NSMutableDictionary *payload = [[NSMutableDictionary alloc]init];
    [payload setObject:@"iOS" forKey:@"platform"];
    [payload setObject:@"3.4.3" forKey:@"cp_version"];
    NSMutableDictionary *logData = [[NSMutableDictionary alloc]init];
    [logData setObject:apiKey forKey:@"partner_id"];
    [logData setObject:@"2.16.6" forKey:@"build"];
    [logData setObject:@"https://github.com/opentok/cordova-plugin-opentok" forKey:@"source"];
    [logData setObject:@"info" forKey:@"payload_type"];
    [logData setObject:payload forKey:@"payload"];
    [logData setObject:sessionId forKey:@"session_id"];
    if (connectionId != nil) {
        [logData setObject:connectionId forKey:@"connectionId"];
        [logData setObject:@"cp_on_connect" forKey:@"action"];
    } else {
        [logData setObject:@"cp_initialize" forKey:@"action"];
    }
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:logData options:NSJSONWritingPrettyPrinted error:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error Logging");
        } else {
            NSLog(@"Logged");
        }
    }] resume];
}

// Called by TB.initsession()
-(void)initSession:(CDVInvokedUrlCommand*)command{
    // Get Parameters
    apiKey = [command.arguments objectAtIndex:0];
    sessionId = [command.arguments objectAtIndex:1];

    // Create Session
    _session = [[OTSession alloc] initWithApiKey: apiKey sessionId:sessionId delegate:self];

    // Initialize Dictionary, contains DOM info for every stream
    subscriberDictionary = [[NSMutableDictionary alloc] init];
    streamDictionary = [[NSMutableDictionary alloc] init];
    connectionDictionary = [[NSMutableDictionary alloc] init];
    observersDictionary = [[NSMutableDictionary alloc] init];

    // OT log request
    [self logOT: nil];
    // Return Result
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// Called by TB.initPublisher()
- (void)initPublisher:(CDVInvokedUrlCommand *)command{
    NSLog(@"iOS creating Publisher");
    /* properties: [name, position.top, position.left, width, height, zIndex,
        publishAudio, publishVideo, cameraName, ratios.widthRatio, ratios.heightRatio,
        audioFallbackEnabled, audioBitrate, audioSource, videoSource, frameRate, cameraResolution]
    */
    // initialize publisher settings
    OTPublisherSettings * _publisherSettings = [[OTPublisherSettings alloc] init];
    BOOL bpubAudio;
    BOOL bpubVideo;
    BOOL baudioFallbackEnabled;
    BOOL bpubAudioTrack;
    BOOL bpubVideoTrack;
    enum OTCameraCaptureFrameRate finalCameraFrameRate;
    enum OTCameraCaptureResolution finalCameraResolution;

    // Get Parameters
    NSString* name = [command.arguments objectAtIndex:0];
    int top = [[command.arguments objectAtIndex:1] intValue];
    int left = [[command.arguments objectAtIndex:2] intValue];
    int width = [[command.arguments objectAtIndex:3] intValue];
    int height = [[command.arguments objectAtIndex:4] intValue];
    int zIndex = [[command.arguments objectAtIndex:5] intValue];
    int audioBitrate = [[command.arguments objectAtIndex:12] intValue];
    int cameraFrameRate = [[command.arguments objectAtIndex: 15] intValue];
    NSString* publishAudio = [command.arguments objectAtIndex:6];
    NSString* publishVideo = [command.arguments objectAtIndex:7];
    NSString* cameraPosition = [command.arguments objectAtIndex:8];
    NSString* audioFallbackEnabled = [command.arguments objectAtIndex: 11];
    NSString* audioTrack = [command.arguments objectAtIndex: 13];
    NSString* videoTrack = [command.arguments objectAtIndex: 14];
    NSString* cameraResolution = [command.arguments objectAtIndex: 16];

    // Sanitize publisher properties
    if ([cameraResolution isEqualToString:@"1280x720"]) {
      finalCameraResolution = OTCameraCaptureResolutionHigh;
    }else if ([cameraResolution isEqualToString:@"320x240"] || [cameraResolution isEqualToString:@"352x288"]) {
      finalCameraResolution = OTCameraCaptureResolutionLow;
    } else {
      finalCameraResolution = OTCameraCaptureResolutionMedium;
    }
    if (cameraFrameRate == 15) {
      finalCameraFrameRate = OTCameraCaptureFrameRate15FPS;
    } else if (cameraFrameRate == 7) {
      finalCameraFrameRate = OTCameraCaptureFrameRate7FPS;
    } else if (cameraFrameRate == 1) {
      finalCameraFrameRate = OTCameraCaptureFrameRate1FPS;
    } else {
      finalCameraFrameRate = OTCameraCaptureFrameRate30FPS;
    }

    bpubAudio = [publishAudio isEqualToString:@"false"] ? NO : YES;
    bpubVideo = [publishVideo isEqualToString:@"false"] ? NO : YES;
    baudioFallbackEnabled = [audioFallbackEnabled isEqualToString:@"false"] ? NO : YES;
    bpubAudioTrack = [audioTrack isEqualToString:@"false"] ? NO : YES;
    bpubVideoTrack = [videoTrack isEqualToString:@"false"] ? NO : YES;

    _publisherSettings.name = name;
    _publisherSettings.audioBitrate = audioBitrate;
    _publisherSettings.audioTrack = bpubAudioTrack;
    _publisherSettings.videoTrack = bpubVideoTrack;
    _publisherSettings.cameraResolution = finalCameraResolution;
    _publisherSettings.cameraFrameRate = finalCameraFrameRate;

    // Publish and set View
    _publisher = [[OTPublisher alloc] initWithDelegate:self settings:_publisherSettings];
    _publisher.networkStatsDelegate = self;
    _publisher.audioLevelDelegate = self;
    [_publisher setPublishAudio:bpubAudio];
    [_publisher setPublishVideo:bpubVideo];
    [_publisher setAudioFallbackEnabled:baudioFallbackEnabled];
    [self.webView.scrollView addSubview:_publisher.view];
    [_publisher.view setFrame:CGRectMake(left, top, width, height)];

    // Set depth location of camera view based on CSS z-index.
    _publisher.view.layer.zPosition = zIndex;

    if ([cameraPosition isEqualToString:@"back"]) {
        _publisher.cameraPosition = AVCaptureDevicePositionBack;
    }

    // Return to Javascript
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}
// Helper function to update Views
- (void)updateView:(CDVInvokedUrlCommand*)command{
    NSString* callback = command.callbackId;
    NSString* sid = [command.arguments objectAtIndex:0];
    int top = [[command.arguments objectAtIndex:1] intValue];
    int left = [[command.arguments objectAtIndex:2] intValue];
    int width = [[command.arguments objectAtIndex:3] intValue];
    int height = [[command.arguments objectAtIndex:4] intValue];
    int zIndex = [[command.arguments objectAtIndex:5] intValue];
    if ([sid isEqualToString:@"TBPublisher"]) {
        NSLog(@"The Width is: %d", width);
        _publisher.view.frame = CGRectMake(left, top, width, height);

        // Set depth location of camera view based on CSS z-index.
        _publisher.view.layer.zPosition = zIndex;

        // If the zIndex is 0(default) bring the view to the top, last one wins.
        // See: https://github.com/saghul/cordova-plugin-iosrtc/blob/5b6a180b324c8c9bac533fa481a457b74183c740/src/PluginMediaStreamRenderer.swift#L191
        if(zIndex == 0) {
            [self.webView.scrollView bringSubviewToFront:_publisher.view];
        }
    }

    // Pulls the subscriber object from dictionary to prepare it for update
    OTSubscriber* streamInfo = [subscriberDictionary objectForKey:sid];

    if (streamInfo) {
        // Reposition the video feeds!
        streamInfo.view.frame = CGRectMake(left, top, width, height);

        // Set depth location of camera view based on CSS z-index.
        streamInfo.view.layer.zPosition = zIndex;

        // If the zIndex is 0(default) bring the view to the top, last one wins.
        // See: https://github.com/saghul/cordova-plugin-iosrtc/blob/5b6a180b324c8c9bac533fa481a457b74183c740/src/PluginMediaStreamRenderer.swift#L191
        if(zIndex == 0) {
            [self.webView.scrollView bringSubviewToFront:_publisher.view];
        }
    }

    CDVPluginResult* callbackResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [callbackResult setKeepCallbackAsBool:YES];
    //[self.commandDelegate sendPluginResult:callbackResult toSuccessCallbackString:command.callbackId];
    [self.commandDelegate sendPluginResult:callbackResult callbackId:command.callbackId];
}

// Helper function to get the base64 image of a view
- (NSString*)getBase64PNGFromUIView:(UIView *)view {
    UIImage *screenshot = [view captureViewImage];
    NSData *imageData = UIImageJPEGRepresentation(screenshot, 1);
    NSString *encodedString = [imageData base64EncodedStringWithOptions:0 ];
    return [NSString stringWithFormat:@"data:image/png;base64,%@",encodedString];
}
    

#pragma mark Publisher Methods
- (void)publishAudio:(CDVInvokedUrlCommand*)command{
    NSString* publishAudio = [command.arguments objectAtIndex:0];
    NSLog(@"iOS Altering Audio publishing state, %@", publishAudio);
    BOOL pubAudio = YES;
    if ([publishAudio isEqualToString:@"false"]) {
        pubAudio = NO;
    }
    [_publisher setPublishAudio:pubAudio];
}
- (void)publishVideo:(CDVInvokedUrlCommand*)command{
    NSString* publishVideo = [command.arguments objectAtIndex:0];
    NSLog(@"iOS Altering Video publishing state, %@", publishVideo);
    BOOL pubVideo = YES;
    if ([publishVideo isEqualToString:@"false"]) {
        pubVideo = NO;
    }
    [_publisher setPublishVideo:pubVideo];
}
- (void)setCameraPosition:(CDVInvokedUrlCommand*)command{
    NSString* publishCameraPosition = [command.arguments objectAtIndex:0];
    NSLog(@"iOS Altering Video camera position, %@", publishCameraPosition);

    if ([publishCameraPosition isEqualToString:@"back"]) {
        [_publisher setCameraPosition:AVCaptureDevicePositionBack];
    } else if ([publishCameraPosition isEqualToString:@"front"]) {
        [_publisher setCameraPosition:AVCaptureDevicePositionFront];
    }
}
- (void)destroyPublisher:(CDVInvokedUrlCommand *)command{
    NSLog(@"iOS Destroying Publisher");
    // Unpublish publisher
    [_session unpublish:_publisher error:nil];

    // Remove publisher view
    if (_publisher) {
        [_publisher.view removeFromSuperview];
    }

    // Return to Javascript
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}
- (void)getImgData:(CDVInvokedUrlCommand*)command{
    NSString* sid = [command.arguments objectAtIndex:0];
    NSString *snapshot;
    OTSubscriber * subscriber;
    
    if ([sid isEqualToString:@"TBPublisher"]) {
        if (_publisher.view) {
            snapshot = [self getBase64PNGFromUIView: _publisher.view];
        }
    } else {
        subscriber = [subscriberDictionary objectForKey:sid];
        if (subscriber) {
            snapshot = [self getBase64PNGFromUIView: subscriber.view];
        }
    }
    
    CDVPluginResult* callbackResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                        messageAsString: snapshot];
    [callbackResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:callbackResult callbackId:command.callbackId];
}

#pragma mark Subscriber Methods
- (void)subscribeToAudio:(CDVInvokedUrlCommand*)command{
    NSString* sid = [command.arguments objectAtIndex:0];
    OTSubscriber * subscriber = [subscriberDictionary objectForKey:sid];
    NSString* val = [command.arguments objectAtIndex:1];
    if (subscriber) {
        BOOL subscribeAudio = YES;
        if ([val isEqualToString:@"false"]) {
            subscribeAudio = NO;
        }
        NSLog(@"setting subscribeToAudio");
        [subscriber setSubscribeToAudio:subscribeAudio];
    }
}
- (void)subscribeToVideo:(CDVInvokedUrlCommand*)command{
    NSString* sid = [command.arguments objectAtIndex:0];
    OTSubscriber * subscriber = [subscriberDictionary objectForKey:sid];
    NSString* val = [command.arguments objectAtIndex:1];
    if (subscriber) {
        BOOL subscribeVideo = YES;
        if ([val isEqualToString:@"false"]) {
            subscribeVideo = NO;
        }
        NSLog(@"setting subscribeToVideo");
        [subscriber setSubscribeToVideo:subscribeVideo];
    }
}



#pragma mark Session Methods
- (void)connect:(CDVInvokedUrlCommand *)command{
    NSLog(@"iOS Connecting to Session");

    // Get Parameters
    OTError *error = nil;
    NSString* tbToken = [command.arguments objectAtIndex:0];
    [_session connectWithToken:tbToken error:&error];
    CDVPluginResult* pluginResult;
    if (error) {
        NSNumber* code = [NSNumber numberWithInt:[error code]];
        NSMutableDictionary* err = [[NSMutableDictionary alloc] init];
        [err setObject:error.localizedDescription forKey:@"message"];
        [err setObject:code forKey:@"code"];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:err];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

}

// Called by session.disconnect()
- (void)disconnect:(CDVInvokedUrlCommand*)command{
    [_session disconnect:nil];
}

// Called by session.publish(top, left)
- (void)publish:(CDVInvokedUrlCommand*)command{
    NSLog(@"iOS Publish stream to session");
    [_session publish:_publisher error:nil];

    // Return to Javascript
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// Called by session.unpublish(...)
- (void)unpublish:(CDVInvokedUrlCommand*)command{
    NSLog(@"iOS Unpublishing publisher");
    @try {
        [_session unpublish:_publisher error:nil];
    } @catch (NSException *exception) {
        NSLog(@"Could not unpublish Publisher");
    }
}

// Called by session.subscribe(streamId, top, left)
- (void)subscribe:(CDVInvokedUrlCommand*)command{
    NSLog(@"iOS subscribing to stream");

    // Get Parameters
    NSString* sid = [command.arguments objectAtIndex:0];


    int top = [[command.arguments objectAtIndex:1] intValue];
    int left = [[command.arguments objectAtIndex:2] intValue];
    int width = [[command.arguments objectAtIndex:3] intValue];
    int height = [[command.arguments objectAtIndex:4] intValue];
    int zIndex = [[command.arguments objectAtIndex:5] intValue];

    // Acquire Stream, then create a subscriber object and put it into dictionary
    OTStream* myStream = [streamDictionary objectForKey:sid];
    OTSubscriber* sub = [[OTSubscriber alloc] initWithStream:myStream delegate:self];
    sub.audioLevelDelegate = self;
    sub.networkStatsDelegate = self;
    [_session subscribe:sub error:nil];

    if ([[command.arguments objectAtIndex:6] isEqualToString:@"false"]) {
        [sub setSubscribeToAudio: NO];
    }
    if ([[command.arguments objectAtIndex:7] isEqualToString:@"false"]) {
        [sub setSubscribeToVideo: NO];
    }
    [subscriberDictionary setObject:sub forKey:myStream.streamId];

    [sub.view setFrame:CGRectMake(left, top, width, height)];

    // Set depth location of camera view based on CSS z-index.
    sub.view.layer.zPosition = zIndex;

    [self.webView.scrollView addSubview:sub.view];

    // Return to JS event handler
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// Called by session.unsubscribe(streamId, top, left)
- (void)unsubscribe:(CDVInvokedUrlCommand*)command{
    NSLog(@"iOS unSubscribing to stream");
    //Get Parameters
    NSString* sid = [command.arguments objectAtIndex:0];
    OTSubscriber * subscriber = [subscriberDictionary objectForKey:sid];
    @try {
        [_session unsubscribe:subscriber error:nil];
        [subscriber.view removeFromSuperview];
        [subscriberDictionary removeObjectForKey:sid];
    } @catch (NSException *exception) {
        NSLog(@"Could not unsubscribe Subscribe");
    }
}

// Called by session.unsubscribe(streamId, top, left)
- (void)signal:(CDVInvokedUrlCommand*)command{
    NSLog(@"iOS signaling to connectionId %@", [command.arguments objectAtIndex:2]);
    OTConnection* c = [connectionDictionary objectForKey: [command.arguments objectAtIndex:2]];
    NSLog(@"iOS signaling to connection %@", c);
    [_session signalWithType:[command.arguments objectAtIndex:0] string:[command.arguments objectAtIndex:1] connection:c error:nil];
}


#pragma mark -
#pragma mark Delegates
#pragma mark Subscriber Delegates
/*** Subscriber Methods
 ****/
- (void)subscriberDidConnectToStream:(OTSubscriberKit*)sub{
    NSLog(@"iOS Connected To Stream");
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    NSString* streamId = sub.stream.streamId;
    [eventData setObject:streamId forKey:@"streamId"];
    [self triggerJSEvent: @"subscriberEvents" withType: @"connected" withData: eventData];
    [self triggerJSEvent: @"sessionEvents" withType: @"subscribedToStream" withData: eventData]; // Backwards compatibility
}
- (void)subscriberDidDisconnectFromStream:(OTSubscriberKit*)sub{
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    NSString* streamId = sub.stream.streamId;
    [eventData setObject:streamId forKey:@"streamId"];
    [self triggerJSEvent: @"subscriberEvents" withType: @"disconnected" withData: eventData];
}
- (void)subscriber:(OTSubscriber*)sub didFailWithError:(OTError*)error{
    NSLog(@"subscriber didFailWithError %@", error);
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    NSString* streamId = sub.stream.streamId;
    NSNumber* errorCode = [NSNumber numberWithInt:1600];
    [eventData setObject: errorCode forKey:@"errorCode"];
    [eventData setObject:streamId forKey:@"streamId"];
    [self triggerJSEvent: @"sessionEvents" withType: @"subscribedToStream" withData: eventData];
}
- (void)subscriberVideoDataReceived:(OTSubscriber*)sub{
    [self triggerJSEvent: @"subscriberEvents" withType: @"videoDataReceived" withData: nil];
}
- (void)subscriberVideoDisabled:(OTSubscriberKit*)sub reason:(OTSubscriberVideoEventReason)reason{
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    NSString* reasonData = [self validateReason: reason];

    [eventData setObject: reasonData forKey:@"reason"];
    [self triggerJSEvent: @"subscriberEvents" withType: @"videoDisabled" withData: eventData];
}
- (void)subscriberVideoDisableWarning:(OTSubscriberKit*)sub{
    [self triggerJSEvent: @"subscriberEvents" withType: @"videoDisableWarning" withData: nil];
}
- (void)subscriberVideoDisableWarningLifted:(OTSubscriberKit*)sub{
    [self triggerJSEvent: @"subscriberEvents" withType: @"videoDisableWarningLifted" withData: nil];
}
- (void)subscriberVideoEnabled:(OTSubscriberKit*)sub reason:(OTSubscriberVideoEventReason)reason{
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    NSString* reasonData = [self validateReason: reason];

    [eventData setObject: reasonData forKey:@"reason"];
    [self triggerJSEvent: @"subscriberEvents" withType: @"videoEnabled" withData: eventData];
}
- (void)subscriber:(OTSubscriberKit*)subscriber audioLevelUpdated:(float)audioLevel{
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    [data setObject: @(audioLevel) forKey: @"audioLevel"];
    [self triggerJSEvent: @"subscriberEvents" withType: @"audioLevelUpdated" withData: data];
}

#pragma mark On property changed
- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqual:@"videoDimensions"]) {
        NSMutableDictionary* newValue = [[NSMutableDictionary alloc] init];
        NSMutableDictionary* oldValue = [[NSMutableDictionary alloc] init];
        if([change objectForKey:NSKeyValueChangeOldKey] != [NSNull null]) {
            CGSize* videoDimensions = (__bridge CGSize*) [change objectForKey:NSKeyValueChangeOldKey];
            [oldValue setObject: @((NSInteger) (floor(videoDimensions->width))) forKey:@"width"];
            [oldValue setObject: @((NSInteger) (floor(videoDimensions->height))) forKey:@"height"];
        }
        if([change objectForKey:NSKeyValueChangeNewKey] != [NSNull null]) {
            CGSize* videoDimensions = (__bridge CGSize*) [change objectForKey:NSKeyValueChangeNewKey];
            [newValue setObject: @((NSInteger) (floor(videoDimensions->width))) forKey:@"width"];
            [newValue setObject: @((NSInteger) (floor(videoDimensions->height))) forKey:@"height"];
        }
        [self onStreamPropertyChanged: keyPath newValue: newValue oldValue: oldValue stream: (__bridge OTStream*) context];
    }
    if ([keyPath isEqual:@"hasAudio"] || [keyPath isEqual:@"hasVideo"]) {
        bool newValue = NO;
        bool oldValue = NO;
        if([change objectForKey:NSKeyValueChangeOldKey] != [NSNull null]) {
            oldValue = [change objectForKey:NSKeyValueChangeOldKey];
        }
        if([change objectForKey:NSKeyValueChangeNewKey] != [NSNull null]) {
            newValue = [change objectForKey:NSKeyValueChangeNewKey];
        }
        [self onStreamPropertyChanged: keyPath newValue: @(newValue) oldValue: @(oldValue) stream: (__bridge OTStream*) context];
    }
}
- (void)onStreamPropertyChanged:(NSString*)changedProperty newValue:(id)newValue oldValue:(id)oldValue stream:(OTStream*)stream{
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* streamData = [self createDataFromStream: stream];

    [eventData setObject: changedProperty forKey:@"changedProperty"];
    [eventData setObject: newValue forKey:@"newValue"];
    [eventData setObject: oldValue forKey:@"oldValue"];
    [eventData setObject: streamData forKey:@"stream"];

    [self triggerJSEvent: @"sessionEvents" withType: @"streamPropertyChanged" withData: eventData];
}

#pragma mark Session Delegates
- (void)sessionDidConnect:(OTSession*)session{
    [self logOT: session.connection.connectionId];
    NSLog(@"iOS Connected to Session");

    NSMutableDictionary* sessionDict = [[NSMutableDictionary alloc] init];

    // SessionConnectionStatus
    NSString* connectionStatus = @"";
    if (session.sessionConnectionStatus==OTSessionConnectionStatusConnected) {
        connectionStatus = @"OTSessionConnectionStatusConnected";
    }else if (session.sessionConnectionStatus==OTSessionConnectionStatusConnecting) {
        connectionStatus = @"OTSessionConnectionStatusConnecting";
    }else if (session.sessionConnectionStatus==OTSessionConnectionStatusDisconnecting) {
        connectionStatus = @"OTSessionConnectionStatusDisconnected";
    }else{
        connectionStatus = @"OTSessionConnectionStatusFailed";
    }
    [sessionDict setObject:connectionStatus forKey:@"sessionConnectionStatus"];

    // SessionId
    [sessionDict setObject:session.sessionId forKey:@"sessionId"];

    [connectionDictionary setObject: session.connection forKey: session.connection.connectionId];


    // After session is successfully connected, the connection property is available
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:@"status" forKey:@"connected"];
    NSMutableDictionary* connectionData = [self createDataFromConnection: session.connection];
    [eventData setObject: connectionData forKey: @"connection"];


    NSLog(@"object for session is %@", sessionDict);

    // After session dictionary is constructed, return the result!
    //    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:sessionDict];
    //    NSString* sessionConnectCallback = [callbackList objectForKey:@"sessSessionConnected"];
    //    [self.commandDelegate sendPluginResult:pluginResult callbackId:sessionConnectCallback];


    [self triggerJSEvent: @"sessionEvents" withType: @"sessionConnected" withData: eventData];
}


- (void)session:(OTSession *)session connectionCreated:(OTConnection *)connection{
    [connectionDictionary setObject: connection forKey: connection.connectionId];
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* connectionData = [self createDataFromConnection: connection];
    [data setObject: connectionData forKey: @"connection"];
    [self triggerJSEvent: @"sessionEvents" withType: @"connectionCreated" withData: data];
}

- (void)session:(OTSession *)session connectionDestroyed:(OTConnection *)connection{
    [connectionDictionary removeObjectForKey: connection.connectionId];
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* connectionData = [self createDataFromConnection: connection];
    [data setObject: connectionData forKey: @"connection"];
    [self triggerJSEvent: @"sessionEvents" withType: @"connectionDestroyed" withData: data];
}
- (void)sessionDidReconnect:(OTSession*)session {
    NSLog(@"iOS Session reconnected");
    [self triggerJSEvent: @"sessionEvents" withType: @"sessionReconnected" withData: nil];
}
- (void)sessionDidBeginReconnecting:(OTSession*)session {
    NSLog(@"iOS Session reconnecting");
    [self triggerJSEvent: @"sessionEvents" withType: @"sessionReconnecting" withData: nil];
}


- (void)session:(OTSession*)mySession streamCreated:(OTStream*)stream{
    NSLog(@"iOS Received Stream");
    [self addObserversToStream: stream];
    [streamDictionary setObject:stream forKey:stream.streamId];
    [self triggerStreamEvent: stream withEventType: @"sessionEvents" subEvent: @"streamCreated"];
}
- (void)session:(OTSession*)session streamDestroyed:(OTStream *)stream{
    NSLog(@"iOS Drop Stream");

    OTSubscriber * subscriber = [subscriberDictionary objectForKey:stream.streamId];
    if (subscriber) {
        NSLog(@"subscriber found, unsubscribing");
        [self removeObserversFromStream: stream];
        [_session unsubscribe:subscriber error:nil];
        [subscriber.view removeFromSuperview];
        [subscriberDictionary removeObjectForKey:stream.streamId];
    }
    [self triggerStreamEvent: stream withEventType: @"sessionEvents" subEvent: @"streamDestroyed"];
}
- (void)session:(OTSession*)session didFailWithError:(OTError*)error {
    NSLog(@"Error: Session did not Connect");
    NSLog(@"Error: %@", error);
    NSNumber* code = [NSNumber numberWithInt:[error code]];
    NSMutableDictionary* err = [[NSMutableDictionary alloc] init];
    [err setObject:error.localizedDescription forKey:@"message"];
    [err setObject:code forKey:@"code"];

    if (self.exceptionId) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: err];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.exceptionId];
    }
}
- (void)sessionDidDisconnect:(OTSession*)session{
    NSString* alertMessage = [NSString stringWithFormat:@"Session disconnected: (%@)", session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);

    // Setting up event object
    for ( id key in subscriberDictionary ) {
        OTSubscriber* aStream = [subscriberDictionary objectForKey:key];
        [aStream.view removeFromSuperview];
    }
    [subscriberDictionary removeAllObjects];
    if( _publisher ){
        [_publisher.view removeFromSuperview];
    }
    // Remove session observers
    for ( id key in streamDictionary ) {
        [self removeObserversFromStream: [streamDictionary objectForKey:key]];
    }

    [streamDictionary removeAllObjects];

    // Setting up event object
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:@"clientDisconnected" forKey:@"reason"];
    [self triggerJSEvent: @"sessionEvents" withType: @"sessionDisconnected" withData: eventData];
}
-(void) session:(OTSession *)session receivedSignalType:(NSString *)type fromConnection:(OTConnection *)connection withString:(NSString *)string{

    NSLog(@"iOS Session Received signal from Connection: %@ with id %@", connection, [connection connectionId]);
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    [data setObject: (type == nil) ? @ "" : type forKey: @"type"];
    [data setObject: (string == nil) ? @"" : string forKey: @"data"];
    if (connection.connectionId) {
        [data setObject: connection.connectionId forKey: @"connectionId"];
    }
    [self triggerJSEvent: @"sessionEvents" withType: @"signalReceived" withData: data];
}
- (void)session:(OTSession*)session archiveStartedWithId:(nonnull NSString *)archiveId name:(NSString *_Nullable)name{
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    [data setObject: archiveId forKey: @"id"];
    [data setObject: (name == nil) ? @"" : name forKey: @"name"];
    [self triggerJSEvent: @"sessionEvents" withType: @"archiveStarted" withData: data];
}
- (void)session:(OTSession*)session archiveStoppedWithId:(nonnull NSString *)archiveId{
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    [data setObject: archiveId forKey: @"id"];
    [self triggerJSEvent: @"sessionEvents" withType: @"archiveStopped" withData: data];
}

#pragma mark Publisher Delegates
- (void)publisher:(OTPublisherKit *)publisher streamCreated:(OTStream *)stream{
    [self addObserversToStream: stream];
    [streamDictionary setObject:stream forKey:stream.streamId];
    [self triggerStreamEvent: stream withEventType: @"publisherEvents" subEvent: @"streamCreated"];
}
- (void)publisher:(OTPublisherKit*)publisher streamDestroyed:(OTStream *)stream{
    [self removeObserversFromStream: stream];
    [streamDictionary removeObjectForKey: stream.streamId];
    [self triggerStreamEvent: stream withEventType: @"publisherEvents" subEvent: @"streamDestroyed"];
}
- (void)publisher:(OTPublisher*)publisher didFailWithError:(NSError*) error {
    NSLog(@"iOS Publisher didFailWithError");
    NSMutableDictionary* err = [[NSMutableDictionary alloc] init];
    [err setObject:error.localizedDescription forKey:@"message"];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: err];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.exceptionId];
}
- (void)publisher:(OTPublisherKit*)publisher audioLevelUpdated:(float)audioLevel{
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    [data setObject: @(audioLevel) forKey: @"audioLevel"];
    [self triggerJSEvent: @"publisherEvents" withType: @"audioLevelUpdated" withData: data];
}



#pragma mark -
#pragma mark Helper Methods
- (NSString*)validateReason: (OTSubscriberVideoEventReason)reason{
    NSString* reasonData = @"";
    if(reason == OTSubscriberVideoEventPublisherPropertyChanged) {
        reasonData = @"publishVideo";
    } else if(reason == OTSubscriberVideoEventSubscriberPropertyChanged) {
        reasonData = @"subscribeToVideo";
    } else if(reason == OTSubscriberVideoEventQualityChanged) {
        reasonData = @"quality";
    }
    return reasonData;
}
- (void)addObserversToStream: (OTStream*) stream{
    BOOL observersAdded = [[observersDictionary objectForKey:stream.streamId] boolValue];
    if (!observersAdded) {
        [observersDictionary setObject: [NSNumber numberWithBool:YES] forKey: stream.streamId];
        // Add observers
        [stream addObserver:self forKeyPath:@"hasAudio" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:(__bridge void * _Nullable)(stream)];
        [stream addObserver:self forKeyPath:@"hasVideo" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:(__bridge void * _Nullable)(stream)];
        [stream addObserver:self forKeyPath:@"videoDimensions" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:(__bridge void * _Nullable)(stream)];
        [stream addObserver:self forKeyPath:@"videoType" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:(__bridge void * _Nullable)(stream)];
    }
}
- (void)removeObserversFromStream: (OTStream*) stream{
   BOOL observersAdded = [[observersDictionary objectForKey:stream.streamId] boolValue];
    if (observersAdded) {
        [observersDictionary removeObjectForKey: stream.streamId];
        // Removing observers
        [stream removeObserver:self forKeyPath:@"hasAudio"];
        [stream removeObserver:self forKeyPath:@"hasVideo"];
        [stream removeObserver:self forKeyPath:@"videoDimensions"];
        [stream removeObserver:self forKeyPath:@"videoType"];
    }
}
- (void)triggerStreamEvent: (OTStream*) stream withEventType: (NSString*) eventType subEvent: (NSString*) subEvent{
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    NSMutableDictionary* streamData = [self createDataFromStream: stream];
    [data setObject: streamData forKey: @"stream"];
    [self triggerJSEvent: eventType withType: subEvent withData: data];
}
- (NSMutableDictionary*)createDataFromConnection:(OTConnection*)connection{
    NSLog(@"iOS creating data from stream: %@", connection);
    NSMutableDictionary* connectionData = [[NSMutableDictionary alloc] init];
    [connectionData setObject: connection.connectionId forKey: @"connectionId" ];
    [connectionData setObject: [NSString stringWithFormat:@"%.0f", [connection.creationTime timeIntervalSince1970]] forKey: @"creationTime" ];
    if (connection.data) {
        [connectionData setObject: connection.data forKey: @"data" ];
    }
    return connectionData;
}
- (NSMutableDictionary*)createDataFromStream:(OTStream*)stream{
    NSMutableDictionary* streamData = [[NSMutableDictionary alloc] init];
    [streamData setObject: stream.connection.connectionId forKey: @"connectionId" ]; // Backwards compatibility.
    [streamData setObject: [self createDataFromConnection: stream.connection] forKey: @"connection"];
    [streamData setObject: [NSString stringWithFormat:@"%.0f", [stream.creationTime timeIntervalSince1970]] forKey: @"creationTime" ];
    [streamData setObject: [NSNumber numberWithInt:-999] forKey: @"fps" ];
    [streamData setObject: [NSNumber numberWithBool: stream.hasAudio] forKey: @"hasAudio" ];
    [streamData setObject: [NSNumber numberWithBool: stream.hasVideo] forKey: @"hasVideo" ];

    NSMutableDictionary* videoDimensions = [[NSMutableDictionary alloc] init];
    CGSize dimensions = stream.videoDimensions;
    [videoDimensions setObject: @((NSInteger) (floor(dimensions.width))) forKey:@"width"];
    [videoDimensions setObject: @((NSInteger) (floor(dimensions.height))) forKey:@"height"];
    [streamData setObject: videoDimensions forKey:@"videoDimensions"];

    NSString* videoType = @"custom";
    if(stream.videoType == OTStreamVideoTypeCamera) {
        videoType = @"camera";
    } else if(stream.videoType == OTStreamVideoTypeScreen) {
        videoType = @"screen";
    }
    [streamData setObject: videoType forKey:@"videoType"];

    [streamData setObject: stream.name forKey: @"name" ];
    [streamData setObject: stream.streamId forKey: @"streamId" ];
    return streamData;
}
- (void)triggerJSEvent:(NSString*)event withType:(NSString*)type withData:(id) data{
    NSMutableDictionary* message = [[NSMutableDictionary alloc] init];
    [message setObject:type forKey:@"eventType"];
    if (data) {
        [message setObject:data forKey:@"data"];
    }
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [pluginResult setKeepCallbackAsBool:YES];

    NSString* callbackId = [callbackList objectForKey:event];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}



/***** Notes


 NSString *stringObtainedFromJavascript = [command.arguments objectAtIndex:0];
 CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: stringObtainedFromJavascript];

 if(YES){
 [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackID]];
 }else{
 //Call  the Failure Javascript function
 [self.commandDelegate [pluginResult toErrorCallbackString:self.callbackID]];
 }

 ******/


@end
