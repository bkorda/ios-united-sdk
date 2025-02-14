//
//  LoopMeInterstitialManager.m
//  LoopMeSDK
//
//  Created by Dmitriy Lihachov on 07/11/13.
//  Copyright (c) 2013 LoopMe. All rights reserved.
//
#import <LoopMeUnitedSDK/LoopMeUnitedSDK-Swift.h>

#import "LoopMeAdManager.h"
#import "LoopMeDefinitions.h"
#import "LoopMeInterstitialViewController.h"
#import "LoopMeAdDisplayControllerNormal.h"
#import "LoopMeLogging.h"
#import "LoopMeORTBTools.h"
#import "LoopMeError.h"

#import "LoopMeInterstitialGeneral.h"
#import "LoopMeAdView.h"

NSString * const kLoopMeAPIURL = @"https://loopme.me/api/ortb/ads";

@interface LoopMeAdManager ()
<
    LoopMeServerCommunicatorDelegate
>

@property (nonatomic, strong) LoopMeServerCommunicator *communicator;
@property (nonatomic, assign, readwrite, getter = isReady) BOOL ready;
@property (nonatomic, assign, readwrite, getter = isLoading) BOOL loading;

@property (nonatomic, strong) NSTimer *adExpirationTimer;
@property (nonatomic, assign) NSInteger expirationTime;

@property (nonatomic, strong) NSString *appKey;
@property (nonatomic, strong) LoopMeTargeting *targeting;
@property (nonatomic, strong) NSString *integrationType;
@property (nonatomic, assign) CGSize adSpotSize;
@property (nonatomic, assign) LoopMeAdType adTypes;
@property (nonatomic, weak) id adUnit;

@property (nonatomic, assign) BOOL swapRequest;

@end

@implementation LoopMeAdManager

#pragma mark - Life Cycle

- (void)dealloc {
    [self invalidateTimers];
    [_communicator cancel];    
}

- (instancetype)initWithDelegate:(id<LoopMeAdManagerDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
        _communicator = [[LoopMeServerCommunicator alloc] initWithDelegate:self];
    }
    return self;
}

#pragma mark - Private

- (void)loadAdWithURL:(NSURL *)URL requestBody:(NSData *)body {
    
    if (self.isLoading) {
        LoopMeLogInfo(@"Interstitial is already loading an ad. Wait for previous load to finish");
        return;
    }

    self.loading = YES;
    LoopMeLogInfo(@"Did start loading ad");
    LoopMeLogDebug(@"loads ad with URL %@", [URL absoluteString]);
    [self.communicator loadWithUrl:URL requestBody:body method:@"POST"];
}

- (void)scheduleAdExpirationIn:(NSTimeInterval)interval {
    self.adExpirationTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                            target:self
                                                          selector:@selector(adContentBecameExpired)
                                                          userInfo:nil
                                                           repeats:NO];
}

- (void)adContentBecameExpired {
    [self invalidateTimers];
    LoopMeLogDebug(@"Ad content is expired");
    if ([self.delegate respondsToSelector:@selector(adManagerDidExpireAd:)]) {
        [self.delegate adManagerDidExpireAd:self];
    }
}

- (BOOL)isAdType:(LoopMeAdType)adType1 equalTo:(LoopMeAdType)adType2 {
    return (adType1 & adType2) == adType2;
}

#pragma mark - Public

- (void)loadURL:(NSURL *)url {
    self.swapRequest = NO;
    [self.communicator loadWithUrl:url requestBody:nil method:@"GET"];
}

- (void)loadAdWithAppKey:(NSString *)appKey targeting:(LoopMeTargeting *)targeting
         integrationType:(NSString *)integrationType adSpotSize:(CGSize)size adSpot:(id)adSpot preferredAdTypes:(LoopMeAdType)adTypes {
    
    self.appKey = appKey;
    self.communicator.appKey = appKey;
    self.targeting = targeting;
    self.integrationType = integrationType;
    self.adSpotSize = size;
    self.adUnit = adSpot;
    self.adTypes = adTypes;
    
    NSData *requestBody;
    BOOL isInterstitial = [self.adUnit isKindOfClass:[LoopMeInterstitialGeneral class]] ? YES : NO;
    
    LoopMeORTBTools *rtbTools = [[LoopMeORTBTools alloc] initWithAppKey:appKey targeting:targeting adSpotSize:size integrationType:integrationType isInterstitial:isInterstitial];
    
    if ([adSpot isKindOfClass:[LoopMeAdView class]]) {
        self.swapRequest = YES;
    }
    
    rtbTools.banner = [self isAdType:adTypes equalTo:LoopMeAdTypeHTML];
    rtbTools.video = [self isAdType:adTypes equalTo:LoopMeAdTypeVideo];
    
    requestBody = [rtbTools makeRequestBody];
    
    if (self.testServerBaseURL) {
        #pragma mark TODO: make request
        [self loadAdWithURL:[NSURL URLWithString:kLoopMeAPIURL] requestBody:requestBody];
    } else {
        [self loadAdWithURL:[NSURL URLWithString:kLoopMeAPIURL] requestBody:requestBody];
    }
}

- (void)invalidateTimers {
    [self.adExpirationTimer invalidate];
    self.adExpirationTimer = nil;
}

#pragma mark - LoopMeServerCommunicatorDelegate

- (void)serverCommunicator:(LoopMeServerCommunicator *)communicator didReceive:(LoopMeAdConfiguration *)adConfiguration {
    
    LoopMeLogDebug(@"Did receive ad configuration: %@", adConfiguration);
        adConfiguration.appKey = self.appKey;
    //    self.expirationTime = adConfiguration.expirationTime;
    if ([self.delegate respondsToSelector:@selector(adManager:didReceiveAdConfiguration:)]) {
        [self.delegate adManager:self didReceiveAdConfiguration:adConfiguration];
    }
    self.loading = NO;
}

- (void)serverCommunicatorDidReceiveAd:(LoopMeServerCommunicator *)communicator {
    if ([self.delegate respondsToSelector:@selector(adManagerDidReceiveAd:)]) {
        [self.delegate adManagerDidReceiveAd:self];
    }
    self.loading = NO;
    [self scheduleAdExpirationIn:self.expirationTime];
    
    self.swapRequest = NO;
}

- (void)serverCommunicator:(LoopMeServerCommunicator *)communicator didFailWith:(NSError *)error {
    self.loading = NO;
    if (self.swapRequest) {
        LoopMeLogDebug(@"Ad failed to load with error: %@", error);
        
        if ([self.delegate respondsToSelector:@selector(adManager:didFailToLoadAdWithError:)]) {
            [self.delegate adManager:self didFailToLoadAdWithError:error];
        }
        self.swapRequest = NO;
    } else {
        self.swapRequest = YES;
        CGSize swapedSize = CGSizeMake(self.adSpotSize.height, self.adSpotSize.width);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadAdWithAppKey:self.appKey targeting:self.targeting integrationType:self.integrationType adSpotSize:swapedSize adSpot:self.adUnit preferredAdTypes:self.adTypes];
        });
    }
}

@end
