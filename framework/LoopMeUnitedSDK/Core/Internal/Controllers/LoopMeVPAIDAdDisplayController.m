//
//  LoopMeVPAIDAdDisplayController.m
//  LoopMeSDK
//
//  Copyright (c) 2016 LoopMe. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <LOOMoatMobileAppKit/LOOMoatAnalytics.h>
#import <LOOMoatMobileAppKit/LOOMoatWebTracker.h>
#import <LoopMeUnitedSDK/LoopMeUnitedSDK-Swift.h>

#import "LoopMeSDK.h"
#import "LoopMeIASWrapper.h"
#import "LoopMeVPAIDClient.h"
#import "LoopMeVPAIDAdDisplayController.h"
#import "LoopMeDestinationDisplayController.h"
#import "LoopMeVPAIDVideoClient.h"
#import "LoopMeVASTImageDownloader.h"
#import "LoopMeVPAIDError.h"
#import "LoopMeError.h"
#import "LoopMeLogging.h"
#import "LoopMeAdWebView.h"
#import "LoopMeErrorEventSender.h"
#import "LoopMeDefinitions.h"
#import "LoopMeCloseButton.h"
#import "LoopMeAdDisplayControllerNormal.h"
#import "LoopMeViewabilityProtocol.h"
#import "LoopMeViewabilityManager.h"
#import "LoopMeOMIDWrapper.h"
#import "LoopMeOMIDVideoEventsWrapper.h"
#import "LoopMeVpaidScriptMessageHandler.h"

NSInteger const kLoopMeVPAIDImpressionTimeout = 2;

NSString * const _kLoopMeVPAIDAdLoadedCommand = @"vpaidAdLoaded";
NSString * const _kLoopMeVPAIDAdPlayingCommand = @"vpaidAdPlaying";
NSString * const _kLoopMeVPAIDAdStartedCommand = @"vpaidAdStarted";
NSString * const _kLoopMeVPAIDAdAdDurationChangeCommand = @"vpaidAdDurationChange";
NSString * const _kLoopMeVPAIDAdImpressionCommand = @"vpaidAdImpression";
NSString * const _kLoopMeVPAIDAdVideoStartCommand = @"vpaidAdVideoStart";
NSString * const _kLoopMeVPAIDAdVideoFirstQuartileCommand = @"vpaidAdVideoFirstQuartile";
NSString * const _kLoopMeVPAIDAdVideoMidpointCommand = @"vpaidAdVideoMidpoint";
NSString * const _kLoopMeVPAIDAdVideoThirdQuartileCommand = @"vpaidAdVideoThirdQuartile";
NSString * const _kLoopMeVPAIDAdVideoCompleteCommand = @"vpaidAdVideoComplete";
NSString * const _kLoopMeVPAIDAdStoppedCommand = @"vpaidAdStopped";
NSString * const _kLoopMeVPAIDAdSkippedCommand = @"vpaidAdSkipped";
NSString * const _kLoopMeVPAIDAdPausedCommand = @"vpaidAdPaused";
NSString * const _kLoopMeVPAIDAdClickThruCommand = @"vpaidAdClickThru";
NSString * const _kLoopMeVPAIDAdVolumeChangedCommand = @"vpaidAdVolumeChange";

NSString * const _kLoopMeVPAIDAdSkippableStateChangeCommand = @"vpaidAdSkippableStateChange";
NSString * const _kLoopMeVPAIDAdSizeChangeCommand = @"vpaidAdSizeChange";
NSString * const _kLoopMeVPAIDAdLinearChangeCommand = @"vpaidAdLinearChange";
NSString * const _kLoopMeVPAIDAdExpandedChangeCommand = @"vpaidAdExpandedChange";
NSString * const _kLoopMeVPAIDAdRemainingTimeChangeCommand = @"vpaidAdRemainingTimeChange";
NSString * const _kLoopMeVPAIDAdInteractionCommand = @"vpaidAdInteraction";

NSString * const _kLoopMeVPAIDAdUserAcceptInvitationCommand = @"vpaidAdUserAcceptInvitation";
NSString * const _kLoopMeVPAIDAdUserMinimizeCommand = @"vpaidAdUserMinimize";
NSString * const _kLoopMeVPAIDAdUserAdUserCloseCommand = @"vpaidAdUserClose";
NSString * const _kLoopMeVPAIDAdLogCommand = @"vpaidAdLog";
NSString * const _kLoopMeVPAIDAdErrorCommand = @"vpaidAdError";


@interface LoopMeVPAIDAdDisplayController ()
<
    LoopMeVPAIDVideoClientDelegate,
    LoopMeVASTImageDownloaderDelegate,
    LoopMeVpaidProtocol,
    WKUIDelegate,
    WKNavigationDelegate
>

@property (nonatomic, strong) LoopMeCloseButton *closeButton;

@property (nonatomic, strong) LoopMeVPAIDClient *vpaidClient;
@property (nonatomic, strong) LoopMeVASTImageDownloader *imageDownloader;

@property (nonatomic, assign) NSInteger loadImageCounter;
@property (nonatomic, assign) NSInteger loadVideoCounter;

@property (nonatomic, strong) NSTimer *impressionTimeOutTimer;
@property (nonatomic, strong) NSTimer *showCloseButtonTimer;

@property (nonatomic, strong) LoopMeVASTEventTracker *vastEventTracker;
@property (nonatomic, strong) LoopMeVpaidScriptMessageHandler *vpaidMessageHandler;
@property (nonatomic, strong) LOOMoatWebTracker *moatTracker;

@property (nonatomic, assign) BOOL needCloseCallback;
@property (nonatomic, assign) BOOL isNeedJSInject;
@property (nonatomic, assign) BOOL isNotPlay;
@property (nonatomic, assign) BOOL isVideoVPAID;
@property (nonatomic, assign) BOOL isDeferredAdStopped;
@property (nonatomic, assign) BOOL isTimerCloseButtonPaused;

@property (nonatomic, assign) double videoDuration;
@property (nonatomic, assign) double lastVolume;
@property (nonatomic, assign) double currentVolume;
@property (nonatomic, assign) int showCloseButtonTimerCounter;
@property (nonatomic, assign) double adRemainingTime;

@property (nonatomic, strong) LoopMeIASWrapper *iasWrapper;
@property (nonatomic, assign) NSTimeInterval viewableTime;
@property (nonatomic, assign) NSTimeInterval previousVideoTime;

@property (nonatomic, strong) OMIDLoopmeAdSession* omidSession;
@property (nonatomic, strong) OMIDLoopmeAdEvents *omidAdEvents;
@property (nonatomic, strong) LoopMeOMIDVideoEventsWrapper *omidVideoEvents;
@property (nonatomic, strong) LoopMeOMIDWrapper *omidWrapper;

- (void)handleVpaidStop;

@end

@implementation LoopMeVPAIDAdDisplayController

#pragma mark - Properties

- (LoopMeVASTImageDownloader *)imageDownloader {
    if (_imageDownloader == nil) {
        _imageDownloader = [[LoopMeVASTImageDownloader alloc] initWithDelegate:self];
    }
    return _imageDownloader;
}

- (void)setVisible:(BOOL)visible {
    if (self.isNotPlay) {
        return;
    }
    if (super.visible != visible) {
        super.visible = visible;
        if (visible) {
            [self.videoClient resume];
            [self.vpaidClient resumeAd];
        } else {
            [self.videoClient pause];
            [self.vpaidClient pauseAd];
        }
    }
}

- (double)videoDuration {
    if (_videoDuration <= 0) {
        _videoDuration = self.adConfiguration.vastProperties.duration;
    }
    return _videoDuration;
}

- (UIButton *)closeButton {
    if (!_closeButton) {
        _closeButton = [[LoopMeCloseButton alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        [_closeButton addTarget:self action:@selector(closeAdByButton) forControlEvents:UIControlEventTouchUpInside];
    }
    return _closeButton;
}

- (CGRect)frameForCloseButton:(CGRect)superviewFrame {
    return CGRectMake(superviewFrame.size.width - 50, 0, 50, 50);
}

#pragma mark - Life Cycle

- (void)dealloc {
    [self.omidSession finish];
    self.webView.navigationDelegate = nil;
    self.webView.UIDelegate = nil;
    self.vastEventTracker = nil;
}

- (instancetype)initWithDelegate:(id<LoopMeAdDisplayControllerDelegate>)delegate {
    
    self = [super initWithDelegate:delegate];
    
    if (self) {
        _iasWrapper = [[LoopMeIASWrapper alloc] init];
        _omidWrapper = [[LoopMeOMIDWrapper alloc] init];
        
        if ([self.adConfiguration useTracking:LoopMeTrackerNameMoat]) {
            LOOMoatOptions *options = [[LOOMoatOptions alloc] init];
            options.debugLoggingEnabled = true;
            [[LOOMoatAnalytics sharedInstance] startWithOptions:options];
            _moatTracker = [LOOMoatWebTracker trackerWithWebComponent:self.webView];
        }
    }
    return self;
}

#pragma mark - Public

- (void)startAd {
    [self.vpaidClient startAd];
    self.impressionTimeOutTimer = [NSTimer scheduledTimerWithTimeInterval:kLoopMeVPAIDImpressionTimeout target:self selector:@selector(vpaidAdImpression) userInfo:nil repeats:NO];
    
    [self.closeButton removeFromSuperview];
    
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeImpression];
//    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearCreativeView];
    NSError *impError;
    [self.omidAdEvents impressionOccurredWithError:&impError];
}

- (void)setAdConfiguration:(LoopMeAdConfiguration *)configuration {
    if (configuration) {
        super.adConfiguration = configuration;
        
        self.vastEventTracker = [[LoopMeVASTEventTracker alloc] initWithTrackingLinks:configuration.vastProperties.trackingLinks];
        
        if (!configuration.vastProperties.isVpaid) {
            NSError *error;
            self.omidSession = [self.omidWrapper sessionForType:OMIDLoopmeCreativeTypeNativeVideo resources:configuration.vastProperties.adVerifications webView:nil error:&error];
            
            // to signal impression event
            NSError *aErr;
            self.omidAdEvents = [[OMIDLoopmeAdEvents alloc] initWithAdSession:self.omidSession error:&aErr];
            
            // to signal video events
            NSError *vErr;
            self.omidVideoEvents = [[LoopMeOMIDVideoEventsWrapper alloc] initWithAdSession:self.omidSession error:&vErr];
            
            self.videoClient = [[LoopMeVPAIDVideoClient alloc] initWithDelegate:self];
            ((LoopMeVPAIDVideoClient *)self.videoClient).configuration = configuration;
            ((LoopMeVPAIDVideoClient *)self.videoClient).eventSender = self.vastEventTracker;
        }
    }
}

- (void)initWebView {
    self.vpaidMessageHandler = [[LoopMeVpaidScriptMessageHandler alloc] init];
    self.vpaidMessageHandler.vpaidCommandProcessor = self;
    
    WKUserContentController *controller = [[WKUserContentController alloc] init];
    [controller addScriptMessageHandler:self.vpaidMessageHandler name:@"vpaid"];
    
    [self initializeWebViewWithContentController:controller];
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
}

- (void)loadAdConfiguration {
    [self initWebView];
    
    self.loadImageCounter = 0;
    self.loadVideoCounter = 0;
    self.needCloseCallback = YES;
    self.isNotPlay = YES;
    
    [self.omidSession start];
    
    if (self.adConfiguration.vastProperties.isVpaid) {
        NSString *htmlString = [self stringFromFile:@"loopmead" withExtension:@"html"];
        
        if (htmlString) {
            htmlString = [self injectAdVerification:htmlString];
        } else {
            [self.delegate adDisplayController:self didFailToLoadAdWithError:[LoopMeError errorForStatusCode:LoopMeErrorCodeNoResourceBundle]];
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *finalHTML = [NSString stringWithFormat:htmlString, self.adConfiguration.vastProperties.assetLinks.vpaidURL];
            [self.webView loadHTMLString:finalHTML baseURL:[NSURL URLWithString:kLoopMeBaseURL]];
        });
        
        self.webViewTimeOutTimer = [NSTimer scheduledTimerWithTimeInterval:kLoopMeWebViewLoadingTimeout target:self selector:@selector(cancelWebView) userInfo:nil repeats:NO];
    } else {
        if ([self.adConfiguration useTracking:LoopMeTrackerNameIas]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.iasWrapper initWithPartnerVersion:LOOPME_SDK_VERSION creativeType:self.adConfiguration.creativeType adConfiguration:self.adConfiguration];
                [self.iasWrapper registerAdView:self.delegate.containerView];
//                [self.iasWrapper registerFriendlyObstruction:self.webView];
            });
        }
        
        self.isNeedJSInject = NO;
    
        NSURL *imageURL;
        if (self.adConfiguration.vastProperties.assetLinks.endCard.count) {
            imageURL = [NSURL URLWithString:[self.adConfiguration.vastProperties.assetLinks.endCard objectAtIndex:self.loadImageCounter]];
        }
        [self.imageDownloader loadImageWithURL:imageURL];
    }
}

- (void)displayAd {
    if ([self.adConfiguration useTracking:LoopMeTrackerNameIas]) {
        [self.iasWrapper recordReadyEvent];
        [self.iasWrapper recordAdLoadedEvent];
    }
    
    self.isNotPlay = NO;
    self.isDeferredAdStopped = NO;
    self.viewableTime = 0;
    
    ((LoopMeVPAIDVideoClient *)self.videoClient).viewController = [self.delegate viewControllerForPresentation];
    CGRect adjustedFrame = [self adjusFrame:self.delegate.containerView.bounds];
    [self.videoClient adjustViewToFrame:adjustedFrame];
    
    if (self.adConfiguration.vastProperties.isVpaid) {
        [self.delegate.containerView addSubview:self.webView];
        [self.delegate.containerView bringSubviewToFront:self.webView];
    
        NSArray *constraintsH = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[webview]-0-|" options:0 metrics:nil views:@{@"webview" : self.webView}];
        NSArray *constraintsV = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[webview]-0-|" options:0 metrics:nil views:@{@"webview" : self.webView}];
        [self.delegate.containerView addConstraints:constraintsH];
        [self.delegate.containerView addConstraints:constraintsV];
    }
    
    [(LoopMeVPAIDVideoClient *)self.videoClient willAppear];
    [self.vastEventTracker trackAdVerificationNonExecuted];
    
    self.omidSession.mainAdView = self.delegate.containerView;
    
//    [self.omidSession addFriendlyObstruction:self.webView];
//    [self.omidSession addFriendlyObstruction:[(LoopMeVPAIDVideoClient *)self.videoClient vastUIView]];
//    [self.omidSession addFriendlyObstruction:[(LoopMeVPAIDVideoClient *)self.videoClient videoView]];
    
    //AVID
    [self.iasWrapper recordAdImpressionEvent];
}

- (void)closeAd {
    self.needCloseCallback = NO;
    [self.showCloseButtonTimer invalidate];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.webView loadHTMLString:@"about:blank" baseURL:nil];
        [self closeAdPrivate];
        [self removeWebView];
    });
}

- (void)removeWebView {
    [self.webView loadHTMLString:@"about:blank" baseURL:nil];
    [self.webView stopLoading];
    [self.webView removeFromSuperview];
    [self.webView.configuration.userContentController removeAllUserScripts];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"mraid"];
}

- (void)closeAdPrivate {
    self.visible = NO;
    [self.videoClient cancel];
    self.videoClient = nil;
    if (!self.isNotPlay) {
        [self.videoClient pause];
        //TODO check on skip
        [self.vpaidClient stopAd];
    }
    
    if ([self.adConfiguration useTracking:LoopMeTrackerNameIas]) {
        [self.iasWrapper clean];
        [self.iasWrapper unregisterAdView:self.webView];
        [self.iasWrapper endSession];
    }
    
    [self.omidSession finish];
    self.omidSession = nil;
}

- (void)closeAdByButton {
    self.needCloseCallback = YES;
    [self closeAdPrivate];
}

- (void)layoutSubviews {
    CGRect adjustedFrame = [self adjusFrame:self.delegate.containerView.bounds];
    [self.videoClient adjustViewToFrame:adjustedFrame];
}

- (void)layoutSubviewsToFrame:(CGRect)frame {
    CGRect adjustedFrame = [self adjusFrame:frame];
    [self.videoClient adjustViewToFrame:adjustedFrame];
}

- (void)stopHandlingRequests {
    [super stopHandlingRequests];
}

- (void)moveView:(BOOL)hideWebView {
    [(LoopMeVPAIDVideoClient *)self.videoClient moveView];
    [self displayAd];
    self.webView.hidden = hideWebView;
    ((LoopMeVPAIDVideoClient *)self.videoClient).vastUIView.hidden = hideWebView;
}

- (void)expandReporting {
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearExpand];
}

- (void)collapseReporting {
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearCollapse];
}

- (void)handleVpaidStop {
    
    if (self.destinationIsPresented) {
        self.isDeferredAdStopped = YES;
        return;
    }
    
    if (!self.isNotPlay) {
        [self.vpaidClient stopActionTimeOutTimer];
        [self stopHandlingRequests];
        self.visible = NO;
        self.isNotPlay = YES;
        
        if (self.needCloseCallback && [self.delegate respondsToSelector:@selector(adDisplayControllerShouldCloseAd:)]) {
            [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearClose];
            [self.delegate adDisplayControllerShouldCloseAd:self];
        }
    }
}

#pragma mark - Private

- (NSString *)stringFromFile:(NSString *)filename withExtension:(NSString *)extension {
    NSURL *bundleURL = [[NSBundle mainBundle] URLForResource:@"LoopMeResources" withExtension:@"bundle"];
    if (!bundleURL) {
        return nil;
    }
    NSBundle *resourcesBundle = [NSBundle bundleWithURL:bundleURL];
    NSString *htmlPath = [resourcesBundle pathForResource:filename ofType:extension];
    return [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:NULL];
}

- (NSString *)injectAdVerification:(NSString *)htmlString {
    NSMutableString *copyHTMLstring = [htmlString mutableCopy];
    
    if (self.adConfiguration.vastProperties.adVerifications.count == 0) {
        [copyHTMLstring replaceOccurrencesOfString:@"[SCRIPTPLACE]" withString:@"" options:0 range:NSMakeRange(0, [htmlString length])];
    } else {
        NSMutableString *pattern = [NSMutableString new];
        for (LoopMeAdVerification *verification in self.adConfiguration.vastProperties.adVerifications) {
            [pattern appendString:[NSString stringWithFormat:@"\"%@\",", verification.jsResource]];
        }
        //remove last ','
        if (pattern.length) {
            pattern = [[pattern substringToIndex:[pattern length] - 1] mutableCopy];
        }
        
        [copyHTMLstring replaceOccurrencesOfString:@"[SCRIPTPLACE]" withString:pattern options:0 range:NSMakeRange(0, [htmlString length])];
    }
    
    return copyHTMLstring;
}

- (NSString *)makeVastVerificationHTML {
    NSString *htmlString = [self stringFromFile:@"loopmevast4" withExtension:@"html"];
    htmlString = [self injectAdVerification:htmlString];
    return htmlString;
}

- (CGRect)adjusFrame:(CGRect)frame {
    CGRect result = frame;
    if (!self.adConfiguration.vastProperties.isVpaid && self.isInterstitial && [self adOrientationMatchContainer:frame]) {
        result = CGRectMake(frame.origin.x, frame.origin.y, frame.size.height, frame.size.width);
    }
    
    return result;
}

- (BOOL)isVertical:(CGRect)frame {
    return frame.size.width < frame.size.height;
}

- (BOOL)isDeviceInPortrait {
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    return orientation == UIDeviceOrientationPortrait || orientation == UIDeviceOrientationPortraitUpsideDown;
}

- (BOOL)adOrientationMatchContainer:(CGRect)frame {
    return ([self isVertical:frame] && [self isDeviceInPortrait]) ||
     ([self isDeviceInPortrait] && ![self isVertical:frame]);
}

#pragma mark - WKWebViewDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    NSURL *URL = [navigationAction.request URL];
    NSURL *baseURL = [NSURL URLWithString:kLoopMeBaseURL];
    if (self.adConfiguration.vastProperties.isVpaid && [URL isEqual:baseURL]) {
        self.isNeedJSInject = YES;
    }
    if ([self shouldIntercept:URL navigationType:navigationAction.navigationType]) {
        [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearClickTracking];
        self.isTimerCloseButtonPaused = YES;
        [self.destinationDisplayClient displayDestinationWithURL:URL];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    if ([URL.scheme isEqualToString:@"lmscript"]) {
        if ([URL.host isEqualToString:@"notloaded"]) {
            [self.vastEventTracker trackErrorCode:LoopMeVPAIDErrorCodeVerificationFail];
        }
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    LoopMeLogDebug(@"WebView received an error %@", error);
    if (error.code == -1004) {
        if ([self.delegate respondsToSelector:@selector(adDisplayController:didFailToLoadAdWithError:)]) {
            [self.delegate adDisplayController:self didFailToLoadAdWithError:error];
        }
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (self.isNeedJSInject) {
        self.isNeedJSInject = NO;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.vpaidClient = [[LoopMeVPAIDClient alloc] initWithDelegate:self webView:self.webView];
            
            if ([self.vpaidClient handshakeVersion] > 0) {
                CGRect windowRect = [UIApplication sharedApplication].keyWindow.bounds;
                if ([self isVertical:windowRect]) {
                    [self.vpaidClient initAdWithWidth:windowRect.size.height height:windowRect.size.width viewMode:LoopMeVPAIDViewMode.fullscreen desiredBitrate:720 creativeData:self.adConfiguration.vastProperties.assetLinks.adParameters];
                } else {
                    [self.vpaidClient initAdWithWidth:windowRect.size.width height:windowRect.size.height viewMode:LoopMeVPAIDViewMode.fullscreen desiredBitrate:720 creativeData:self.adConfiguration.vastProperties.assetLinks.adParameters];
                }
            } else {
                [self.delegate adDisplayController:self didFailToLoadAdWithError:[LoopMeVPAIDError errorForStatusCode:LoopMeVPAIDErrorCodeMediaNotFound]];
            }
        });
    }
}

- (void)showCloseButtonTimerTick {
    if (self.isTimerCloseButtonPaused) {
        return;
    }
    self.showCloseButtonTimerCounter += 1;
    NSTimeInterval duration = [self.adConfiguration.vastProperties duration];
    if (self.showCloseButtonTimerCounter >= duration) {
        [self.showCloseButtonTimer invalidate];
        [self showCloseButton];
        return;
    }
}

- (void)showCloseButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.closeButton.frame = [self frameForCloseButton:self.webView.frame];
        [self.delegate.containerView addSubview:self.closeButton];
    });
}

#pragma mark - VpaidClientDelegate

- (void)vpaidJSError:(NSString *)message {
    if (self.isNotPlay) {
        [self stopHandlingRequests];
        NSError *error = [LoopMeVPAIDError errorForStatusCode:LoopMeVPAIDErrorCodeVPAIDError];
        [self.delegate adDisplayController:self didFailToLoadAdWithError:error];
    }
    
    [LoopMeErrorEventSender sendError:LoopMeEventErrorTypeJS errorMessage:message appkey:self.adConfiguration.appKey];
    [self.vastEventTracker trackErrorCode:LoopMeVPAIDErrorCodeVPAIDError];
}

- (void)vpaidAdLoaded:(double)volume {
    LoopMeLogDebug(@"VPAID ad loaded");
    [self.vpaidClient stopActionTimeOutTimer];
    [self.webViewTimeOutTimer invalidate];
    self.webViewTimeOutTimer = nil;
    self.currentVolume = volume;
    self.lastVolume = self.currentVolume;
    
    OMIDLoopmeVASTProperties *vastProperties = [[OMIDLoopmeVASTProperties alloc] initWithSkipOffset:self.adConfiguration.vastProperties.skipOffset.value autoPlay:YES position:OMIDPositionStandalone];
    [self.omidVideoEvents loadedWithVastProperties:vastProperties];
    
    if ([self.delegate respondsToSelector:@selector(adDisplayControllerDidFinishLoadingAd:)]) {
        [self.delegate adDisplayControllerDidFinishLoadingAd:self];
    }
}

- (void)vpaidAdSizeChange:(CGSize)size {
    LoopMeLogDebug(@"VPAID size change");
}

- (void)vpaidAdStarted {
    LoopMeLogDebug(@"VPAID ad started");
    [self.vpaidClient stopActionTimeOutTimer];
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearStart];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.showCloseButtonTimerCounter = 0;
         self.showCloseButtonTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(showCloseButtonTimerTick) userInfo:nil repeats:YES];
    });
}

- (void)vpaidAdPaused {
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearPause];
}

- (void)vpaidAdPlaying {
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearResume];
}

- (void)vpaidAdExpandedChange:(BOOL)expanded {
    LoopMeLogDebug(@"VPAID Ad ExpandedChange");
}

- (void)vpaidAdSkipped {
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearSkip];
    [self handleVpaidStop];
}

- (void)vpaidAdStopped {
    [self handleVpaidStop];
}

- (void)vpaidAdVolumeChanged:(double)volume {
    self.currentVolume = volume;
    
    if (self.currentVolume == 0 && self.lastVolume > 0) {
        [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearMute];
    }
    if (self.currentVolume > 0 && self.lastVolume == 0) {
        [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearUnmute];
    }
    self.lastVolume = self.currentVolume;
}

- (void)vpaidAdSkippableStateChange {
    LoopMeLogDebug(@"VPAID Ad SkippableStateChange");
}

- (void)vpaidAdLinearChange {
    LoopMeLogDebug(@"VPAID Ad LinearChange");
}

- (void)vpaidAdDurationChange {
    if (!self.isVisible) {
        return;
    }
        
    if (self.adRemainingTime < 0) {
        return;
    }
    double currentTime = self.videoDuration - self.adRemainingTime;
    [self.vastEventTracker setCurrentTime:currentTime];
}

- (void)vpaidAdRemainingTimeChange:(double)time {
    self.adRemainingTime = time;
    double currentTime = self.videoDuration - time;
    [self.vastEventTracker setCurrentTime:currentTime];
}

- (void)vpaidAdImpression {
    [self.impressionTimeOutTimer invalidate];
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeImpression];
}

- (void)vpaidAdVideoStart {
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearStart];
}

- (void)vpaidAdVideoFirstQuartile {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.showCloseButtonTimer invalidate];
    });
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearFirstQuartile];
}

- (void)vpaidAdVideoMidpoint {
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearMidpoint];
}

- (void)vpaidAdVideoThirdQuartile {
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearThirdQuartile];
}

- (void)vpaidAdVideoComplete {
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearComplete];
}

- (void)vpaidAdClickThru:(NSString *)url id:(NSString *)Id playerHandles:(BOOL)playerHandles {
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearClickTracking];
    NSString *clickURL = self.adConfiguration.vastProperties.trackingLinks.clickVideo;
    self.isTimerCloseButtonPaused = YES;
    if (playerHandles) {
        if (!!url.length) {
            clickURL = url;
        }
        [self.destinationDisplayClient displayDestinationWithURL:[NSURL URLWithString:clickURL]];
    }
    if ([self.delegate respondsToSelector:@selector(adDisplayControllerDidReceiveTap:)]) {
        [self.delegate adDisplayControllerDidReceiveTap:self];
    }
}

- (void)vpaidAdInteraction:(NSString *)eventID {
    LoopMeLogDebug(@"VPAID Ad interaction: %@", eventID);
}

- (void)vpaidAdUserAcceptInvitation {
    LoopMeLogDebug(@"VPAID Ad UserAcceptInvitation");
}

- (void)vpaidAdUserMinimize {
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearCollapse];
}

- (void)vpaidAdUserClose {
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearClose];
}

- (void)vpaidAdError:(NSString *)error {
    LoopMeLogDebug(@"%@ Vpaid Ad error: ", error);
    [self.vastEventTracker trackErrorCode:LoopMeVPAIDErrorCodeVPAIDError];
    
    if ([self.delegate respondsToSelector:@selector(adDisplayControllerShouldCloseAd:)]) {
        [self.delegate adDisplayControllerShouldCloseAd:self];
    }
}

- (void)vpaidAdLog:(NSString *)message {
    LoopMeLogDebug(message);
}

- (void)vpaidAdVideoSource:(NSString *)videoSource {
    LoopMeLogDebug(videoSource);
    self.isVideoVPAID = YES;
}

- (NSString *)appKey {
    return self.adConfiguration.appKey;
}

#pragma mark - VideoClientDelegate

- (LoopMeVastSkipOffset *)skipOffset {
    return self.adConfiguration.vastProperties.skipOffset;
}

- (void)videoClientDidLoadVideo:(LoopMeVPAIDVideoClient *)client {
    LoopMeLogInfo(@"Did load video ad");
    
    OMIDLoopmeVASTProperties *vastProperties = [[OMIDLoopmeVASTProperties alloc] initWithSkipOffset:self.adConfiguration.vastProperties.skipOffset.value autoPlay:YES position:OMIDPositionStandalone];
    [self.omidVideoEvents loadedWithVastProperties:vastProperties];
    
    if ([self.delegate respondsToSelector:
         @selector(adDisplayControllerDidFinishLoadingAd:)]) {
        [self.delegate adDisplayControllerDidFinishLoadingAd:self];
    }
}

- (void)videoClient:(LoopMeVPAIDVideoClient *)client didFailToLoadVideoWithError:(NSError *)error {
    self.loadVideoCounter++;
    if (self.adConfiguration.vastProperties.assetLinks.videoURL.count > self.loadVideoCounter) {
        [self.vastEventTracker trackErrorCode:error.code];
        [self.videoClient loadWithURL:[NSURL URLWithString:self.adConfiguration.vastProperties.assetLinks.videoURL[self.loadVideoCounter]]];
        return;
    }
    LoopMeLogInfo(@"Did fail to load video ad");
    if ([self.delegate respondsToSelector:
         @selector(adDisplayController:didFailToLoadAdWithError:)]) {
        [self.delegate adDisplayController:self didFailToLoadAdWithError:error];
    }
}

- (void)videoClientDidReachEnd:(LoopMeVPAIDVideoClient *)client {
    LoopMeLogInfo(@"Video ad did reach end");
    if ([self.delegate respondsToSelector:
         @selector(adDisplayControllerVideoDidReachEnd:)]) {
        [self.delegate adDisplayControllerVideoDidReachEnd:self];
    }
}

- (void)videoClient:(LoopMeVPAIDVideoClient *)client setupView:(UIView *)view {
    view.frame = [self adjusFrame:self.delegate.containerView.bounds];
    [self.iasWrapper registerFriendlyObstruction:view];
    [[self.delegate containerView] addSubview:view];
}

- (void)videoClientShouldCloseAd:(LoopMeVPAIDVideoClient *)client {
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeNotViewable];
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearClose];
    if ([self.delegate respondsToSelector:@selector(adDisplayControllerShouldCloseAd:)]) {
        [self.delegate adDisplayControllerShouldCloseAd:self];
    }
}

- (void)videoClientDidVideoTap {
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearClickTracking];
    if (self.adConfiguration.vastProperties.trackingLinks.clickVideo && ![self.adConfiguration.vastProperties.trackingLinks.clickVideo isEqual:@""]) {
        
        self.isEndCardClicked = NO;
        self.isTimerCloseButtonPaused = YES;
        [self.videoClient pause];
        
        [self.destinationDisplayClient displayDestinationWithURL:[NSURL URLWithString:self.adConfiguration.vastProperties.trackingLinks.clickVideo]];
        
        if ([self.delegate respondsToSelector:@selector(adDisplayControllerDidReceiveTap:)]) {
               [self.delegate adDisplayControllerDidReceiveTap:self];
           }
    }
}

- (void)videoClientDidEndCardTap {
    [self.vastEventTracker trackEvent:LoopMeVASTEventTypeCompanionClickTracking];
    if (self.adConfiguration.vastProperties.trackingLinks.clickCompanion && ![self.adConfiguration.vastProperties.trackingLinks.clickCompanion isEqual:@""]) {
        
        self.isEndCardClicked = YES;
        self.isTimerCloseButtonPaused = YES;
        
        [self.destinationDisplayClient displayDestinationWithURL:[NSURL URLWithString:self.adConfiguration.vastProperties.trackingLinks.clickCompanion]];
        
        if ([self.delegate respondsToSelector:@selector(adDisplayControllerDidReceiveTap:)]) {
            [self.delegate adDisplayControllerDidReceiveTap:self];
        }
    }
}

- (void)videoClientDidExpandTap:(BOOL)expand {
    if (expand) {
        if ([self.delegate respondsToSelector:@selector(adDisplayControllerWillExpandAd:)]) {
            [self.delegate adDisplayControllerWillExpandAd:self];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(adDisplayControllerWillCollapse:)]) {
            [self.delegate adDisplayControllerWillCollapse:self];
        }
    }
    [self.videoClient setGravity:AVLayerVideoGravityResizeAspect];
}

- (void)videoClientDidBecomeActive:(LoopMeVPAIDVideoClient *)client {
    [self layoutSubviews];
    if (!self.destinationIsPresented && ![self.videoClient playerReachedEnd] && !self.isEndCardClicked && self.visible) {
        [self.videoClient resume];
    }
}

- (void)currentTime:(NSTimeInterval)currentTime percent:(double)percent {
    if ([[LoopMeViewabilityManager sharedInstance] isViewable:self.delegate.containerView]) {
        self.viewableTime += currentTime - self.previousVideoTime;
    }
    self.previousVideoTime = currentTime;
    //    NSLog(@"viewable time: %f", self.viewableTime);
    //    NSLog(@"current time: %f", currentTime);
    if (self.viewableTime >= 2) {
        [self.vastEventTracker trackEvent:LoopMeVASTEventTypeViewable];
    }
    
    if (percent >= 0.25 && percent < 0.5) {
        [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearFirstQuartile];
        [self.iasWrapper recordAdVideoFirstQuartileEvent];
        [self.omidVideoEvents firstQuartile];
    } else if (percent >= 0.5 && percent < 0.75) {
        [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearMidpoint];
        [self.iasWrapper recordAdVideoMidpointEvent];
        [self.omidVideoEvents midpoint];
    } else if (percent >= 0.75) {
        [self.vastEventTracker trackEvent:LoopMeVASTEventTypeLinearThirdQuartile];
        [self.iasWrapper recordAdVideoThirdQuartileEvent];
        [self.omidVideoEvents thirdQuartile];
    }
    [self.vastEventTracker setCurrentTime:currentTime];
}

#pragma mark - Destination Protocol

- (void)destinationDisplayControllerDidDismissModal:(LoopMeDestinationDisplayController *)destinationDisplayController {
    self.isTimerCloseButtonPaused = NO;
    [super destinationDisplayControllerDidDismissModal:destinationDisplayController];
    
    if (self.isDeferredAdStopped) {
        [self handleVpaidStop];
        [LoopMeErrorEventSender sendError:LoopMeEventErrorTypeCustom errorMessage:@"Deferred adStopped" appkey:self.appKey];
    }
}

- (UIViewController *)viewControllerForPresentingModalView {
    return [self.delegate viewControllerForPresentation];
}

#pragma mark -- VPAID Commands

- (void)processCommand:(NSString *)command withParams:(NSDictionary *)params {
//    LoopMeLogDebug(@"Processing VPAID command: %@, params: %@", command, params);
    
    if ([command isEqualToString:_kLoopMeVPAIDAdLoadedCommand]) {
        double volume = [[params objectForKey:@"volume"] doubleValue];
        [self vpaidAdLoaded:volume];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdPlayingCommand]) {
        [self vpaidAdPlaying];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdStartedCommand]) {
        [self vpaidAdStarted];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdPlayingCommand]) {
        [self vpaidAdPlaying];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdAdDurationChangeCommand]) {
        self.adRemainingTime = [[params objectForKey:@"remainingTime"] doubleValue];
        self.videoDuration = [[params objectForKey:@"duration"] doubleValue];
        [self vpaidAdDurationChange];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdImpressionCommand]) {
        [self vpaidAdImpression];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdVideoStartCommand]) {
        [self vpaidAdVideoStart];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdVideoFirstQuartileCommand]) {
        [self vpaidAdVideoFirstQuartile];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdVideoMidpointCommand]) {
        [self vpaidAdVideoMidpoint];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdVideoThirdQuartileCommand]) {
        [self vpaidAdVideoThirdQuartile];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdVideoCompleteCommand]) {
        [self vpaidAdVideoComplete];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdStoppedCommand]) {
        [self vpaidAdStopped];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdSkippedCommand]) {
        [self vpaidAdSkipped];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdPausedCommand]) {
        [self vpaidAdPaused];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdClickThruCommand]) {
        [self vpaidAdClickThru:[params objectForKey:@"url"] id:[params objectForKey:@"id"] playerHandles:[[params objectForKey:@"playerHandles"] boolValue]];
    } else if([command isEqualToString:_kLoopMeVPAIDAdVolumeChangedCommand]) {
        double volume = [[params objectForKey:@"volume"] doubleValue];
        [self vpaidAdVolumeChanged:volume];
    } else if([command isEqualToString:_kLoopMeVPAIDAdSkippableStateChangeCommand]) {
        BOOL state = [[params objectForKey:@"skipState"] boolValue];
        [self vpaidAdSkippableStateChange];
    } else if([command isEqualToString:_kLoopMeVPAIDAdSizeChangeCommand]) {
        double width = [[params objectForKey:@"width"] doubleValue];
        double height = [[params objectForKey:@"height"] doubleValue];
        [self vpaidAdSizeChange:CGSizeMake(width, height)];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdLinearChangeCommand]) {
        [self vpaidAdLinearChange];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdExpandedChangeCommand]) {
        BOOL expanded = [[params objectForKey:@"expanded"] boolValue];
        [self vpaidAdExpandedChange:expanded];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdRemainingTimeChangeCommand]) {
        double time = [[params objectForKey:@"time"] doubleValue];
        [self vpaidAdRemainingTimeChange:time];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdInteractionCommand]) {
        NSString *identifier = [[params objectForKey:@"id"] stringValue];
        [self vpaidAdInteraction:identifier];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdUserAcceptInvitationCommand]) {
        [self vpaidAdUserAcceptInvitation];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdUserMinimizeCommand]) {
        [self vpaidAdUserMinimize];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdUserAdUserCloseCommand]) {
        [self vpaidAdUserClose];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdLogCommand]) {
        NSString *message = [[params objectForKey:@"message"] stringValue];
        [self vpaidAdLog:message];
    } else if ([command isEqualToString:_kLoopMeVPAIDAdErrorCommand]) {
        NSString *error;
        if ([[params objectForKey:@"error"] isKindOfClass:NSString.class]) {
            error = [params objectForKey:@"error"];
        } else {
            error = [[params objectForKey:@"error"] stringValue];
        }
        [self vpaidAdError:error];
    } else {
        LoopMeLogDebug(@"VPAID command: %@ is not supported", command);
    }
}

#pragma mark - ImageDownloaderDelegate

- (void)imageDownloader:(LoopMeVASTImageDownloader *)downloader didLoadImage:(UIImage *)image withError:(NSError *)error {
    if (error) {
        [self.vastEventTracker trackErrorCode:error.code];
    }
    
    NSURL *videoURL;
    if (self.adConfiguration.vastProperties.assetLinks.videoURL.count != 0) {
        videoURL = [NSURL URLWithString:self.adConfiguration.vastProperties.assetLinks.videoURL[self.loadVideoCounter]];
    }
    self.loadImageCounter++;
    if (image) {
        [((LoopMeVPAIDVideoClient *)self.videoClient).vastUIView setEndCardImage:image];
        [self.videoClient loadWithURL:videoURL];
    } else if (self.adConfiguration.vastProperties.assetLinks.endCard.count > self.loadImageCounter){
        [self.imageDownloader loadImageWithURL:[NSURL URLWithString:self.adConfiguration.vastProperties.assetLinks.endCard[self.loadImageCounter]]];
    } else {
        [self.videoClient loadWithURL:videoURL];
    }
}

@end
