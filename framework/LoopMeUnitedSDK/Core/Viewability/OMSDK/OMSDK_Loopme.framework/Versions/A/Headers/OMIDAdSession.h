//
//  OMIDAdSession.h
//  AppVerificationLibrary
//
//  Created by Daria on 06/06/2017.
//

#import <UIKit/UIKit.h>
#import "OMIDAdSessionContext.h"
#import "OMIDAdSessionConfiguration.h"
#import "OMIDFriendlyObstructionType.h"

/**
 * List of supported error types.
 */
typedef NS_ENUM(NSUInteger, OMIDErrorType) {
    /**
     * The integration is publishing a "generic" error to verification scripts.
     */
    OMIDErrorGeneric = 1,
    /**
     * The integration is publishing a "video" error to verification scripts.
     */
    OMIDErrorMedia = 2,
    /**
     * Same as `OMIDErrorMedia`.  Will be removed in OM SDK 1.3.4.
     */
    OMIDErrorVideo __deprecated_msg("Use OMIDErrorMedia") = 2
};

/**
 *  Ad session API enabling the integration partner to notify OMID of key state relating to viewability calculations.
 * In addition to viewability this API will also notify all verification providers of key ad session lifecycle events.
 */
@interface OMIDLoopmeAdSession : NSObject

/**
 *  The AdSession configuration is used for check owners.
 */
@property(nonatomic, readonly, nonnull) OMIDLoopmeAdSessionConfiguration *configuration;
/**
 *  The native view which is used for viewability tracking.
 */
@property(nonatomic, weak, nullable) UIView *mainAdView;

/**
 *  Initializes new ad session supplying the context.
 *
 * Note that creating an OMIDAdSession sends a message to the OM SDK JS Service running in the
 * webview.  If the OM SDK JS Service has not loaded before the ad session is created, the
 * message is lost, and the verification scripts will not receive any events.
 *
 * To prevent this, the implementation must wait until the webview finishes loading OM SDK
 * JavaScript before creating the OMIDAdSession.  The easiest way is to create the OMIDAdSession
 * in a webview delegate callback (-[WKNavigationDelegate webView:didFinishNavigation:] or
 * -[UIWebViewDelegate webViewDidFinishLoad:]).  Alternatively, if an implementation can receive an
 * HTML5 DOMContentLoaded event from the webview, it can create the OMIDAdSession in a message
 * handler for that event.
 *
 * @param context The context that provides the required information for initialising the ad session.
 * @return A new OMIDAdSession instance, or nil if the supplied context is nil.
 */
- (nullable instancetype)initWithConfiguration:(nonnull OMIDLoopmeAdSessionConfiguration *)configuration
                              adSessionContext:(nonnull OMIDLoopmeAdSessionContext *)context
                                         error:(NSError *_Nullable *_Nullable)error;


/**
 *  Notifies all verification providers that the ad session has started and ad view tracking will begin.
 * 
 *  This method will have no affect if called after the ad session has finished.
 */
- (void)start;

/**
 *  Notifies all verification providers that the ad session has finished and all ad view tracking will stop.
 *
 *  This method will have no affect if called after the ad session has finished.
 *
 * Note that ending an OMID ad session sends a message to the verification scripts running inside
 * the webview supplied by the integration.  So that the verification scripts have enough time to
 * handle the 'sessionFinish' event, the integration must maintain a strong reference to the webview
 * for at least 1.0 seconds after ending the session.
 */
- (void)finish;

/**
 * DEPRECATED.  Adds friendly obstruction which should then be excluded from all ad session
 * viewability calculations.
 *
 * This method will have no affect if called after the ad session has finished.
 *
 * @param friendlyObstruction The view to be excluded from all ad session viewability calculations.
 *
 * @note This will just call `-[OMIDAdSession addFriendlyObstruction:purpose:detailedReason:error:]`
 * with the additional arguments OMIDFriendlyObstructionOther, nil, and nil respectfully.
 *
 * Warning:
 *  * This method will be fully removed in OM SDK 1.3.4 or later. Use `-[OMIDAdSession
 * addFriendlyObstruction:purpose:detailedReason:error:]` instead.
 */
- (void)addFriendlyObstruction:(nonnull UIView *)friendlyObstruction
    __deprecated_msg("Use -[OMIDAdSession addFriendlyObstruction:purpose:detailedReason:error:]");

/**
 *  Adds friendly obstruction which should then be excluded from all ad session viewability calculations.
 * It also provides a purpose and detailed reason string to pass forward to the measurement vendors.
 *
 *  This method will have no affect if called after the ad session has finished.
 *
 * @param friendlyObstruction The view to be excluded from all ad session viewability calculations.
 * @param purpose The purpose of why this obstruction was necessary.
 * @param detailedReason An explanation for why this obstruction is part of the ad experience if not already
 * obvious from the purpose. Can be nil. If not nil, must be 50 characters or less and only contain characers
 * `A-z`, `0-9`, or spaces.
 * @return Whether this friendly obstruction was successfully added. If the session has finished or the
 * friendlyObstruction has already been added for this session, this method will return NO with no associated
 * error object. However, if one or more arguments are against requirements, it will return NO with an error
 * object assigned.
 */
- (BOOL)addFriendlyObstruction:(nonnull UIView *)friendlyObstruction
                       purpose:(OMIDFriendlyObstructionType)purpose
                detailedReason:(nullable NSString *)detailedReason
                         error:(NSError *_Nullable *_Nullable)error;

/**
 *  Removes registered friendly obstruction.
 *
 *  This method will have no affect if called after the ad session has finished.
 *
 * @param friendlyObstruction The view to be removed from the list of registered friendly obstructions.
 */
- (void)removeFriendlyObstruction:(nonnull UIView *)friendlyObstruction;

/**
 *  Utility method to remove all registered friendly obstructions.
 *
 *  This method will have no affect if called after the ad session has finished.
 */
- (void)removeAllFriendlyObstructions;

/**
 *  Notifies the ad session that an error has occurred.
 *
 *  When triggered all registered verification providers will be notified of this event.
 *
 * @param errorType The type of error.
 * @param message The message containing details of the error.
 */
- (void)logErrorWithType:(OMIDErrorType)errorType message:(nonnull NSString *)message
NS_SWIFT_NAME(logError(withType:message:));

@end

