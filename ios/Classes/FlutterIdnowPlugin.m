#import "FlutterIdnowPlugin.h"

#import "IDnowSDK.h"
#import <AVFoundation/AVFoundation.h>

@implementation FlutterIdnowPlugin {
    FlutterResult _result;
    NSDictionary *_arguments;
    __weak NSObject<FlutterPluginRegistrar> *_registrar;
    __weak UIViewController *_sessionRootViewController;
    dispatch_block_t _presentationWatchdog;
    dispatch_block_t _dismissGracePeriodBlock;
    dispatch_block_t _visibilityPollBlock;
    BOOL _identificationSessionStarted;
    BOOL _idnowUiWasEverVisible;
    BOOL _idnowUiCurrentlyVisible;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
            methodChannelWithName:@"flutter_idnow"
                  binaryMessenger:[registrar messenger]];

    FlutterIdnowPlugin* instance = [[FlutterIdnowPlugin alloc] initWithRegistrar:registrar];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    self = [super init];
    if (self) {
        _registrar = registrar;
    }
    return self;
}

- (UIViewController *)topViewController {
    UIViewController *rootViewController = [_registrar viewController];

    if (rootViewController == nil) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundInactive &&
                scene.activationState != UISceneActivationStateForegroundActive) {
                continue;
            }
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow && window.rootViewController != nil) {
                    rootViewController = window.rootViewController;
                    break;
                }
            }

            if (rootViewController != nil) {
                break;
            }
        }
    }

    UIViewController *topController = rootViewController;
    while (topController.presentedViewController != nil) {
        topController = topController.presentedViewController;
    }

    return topController;
}

- (BOOL)isIdnowUiVisibleFromViewController:(UIViewController *)viewController {
    if (viewController == nil) {
        return NO;
    }

    NSString *className = NSStringFromClass([viewController class]);
    if ([className rangeOfString:@"IDnow" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return YES;
    }

    for (UIViewController *child in viewController.childViewControllers) {
        if ([self isIdnowUiVisibleFromViewController:child]) {
            return YES;
        }
    }

    return [self isIdnowUiVisibleFromViewController:viewController.presentedViewController];
}

- (BOOL)isIdentificationSessionUiVisible {
    if ([self isIdnowUiVisibleFromViewController:[self topViewController]]) {
        return YES;
    }

    if (!_identificationSessionStarted) {
        return NO;
    }

    UIViewController *sessionRoot = _sessionRootViewController ?: [self topViewController];
    return sessionRoot.presentedViewController != nil;
}

- (BOOL)isCameraOrMicrophoneDenied {
    AVAuthorizationStatus cameraStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    AVAuthorizationStatus micStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];

    return cameraStatus == AVAuthorizationStatusDenied || cameraStatus == AVAuthorizationStatusRestricted ||
           micStatus == AVAuthorizationStatusDenied || micStatus == AVAuthorizationStatusRestricted;
}

- (BOOL)isCameraOrMicrophonePermissionPending {
    AVAuthorizationStatus cameraStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    AVAuthorizationStatus micStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];

    return cameraStatus == AVAuthorizationStatusNotDetermined || micStatus == AVAuthorizationStatusNotDetermined;
}

- (void)cancelPresentationWatchdog {
    if (_presentationWatchdog != nil) {
        dispatch_block_cancel(_presentationWatchdog);
        _presentationWatchdog = nil;
    }
}

- (void)cancelDismissGracePeriod {
    if (_dismissGracePeriodBlock != nil) {
        dispatch_block_cancel(_dismissGracePeriodBlock);
        _dismissGracePeriodBlock = nil;
    }
}

- (void)cancelVisibilityPoll {
    if (_visibilityPollBlock != nil) {
        dispatch_block_cancel(_visibilityPollBlock);
        _visibilityPollBlock = nil;
    }
}

- (void)stopSessionMonitoring {
    [self cancelPresentationWatchdog];
    [self cancelDismissGracePeriod];
    [self cancelVisibilityPoll];
    _identificationSessionStarted = NO;
    _sessionRootViewController = nil;
}

- (void)markIdentificationSessionStartedWithViewController:(UIViewController *)viewController {
    _identificationSessionStarted = YES;
    _sessionRootViewController = viewController;
    [self cancelPresentationWatchdog];
}

- (void)scheduleVisibilityPoll {
    [self cancelVisibilityPoll];

    __weak typeof(self) weakSelf = self;
    _visibilityPollBlock = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }

        if (strongSelf->_result == nil) {
            [strongSelf stopSessionMonitoring];
            return;
        }

        BOOL visible = [strongSelf isIdentificationSessionUiVisible];
        if (visible) {
            strongSelf->_idnowUiWasEverVisible = YES;
            strongSelf->_idnowUiCurrentlyVisible = YES;
            [strongSelf cancelDismissGracePeriod];
        } else if (strongSelf->_idnowUiCurrentlyVisible) {
            strongSelf->_idnowUiCurrentlyVisible = NO;
            [strongSelf scheduleDismissGracePeriod];
        }

        [strongSelf scheduleVisibilityPoll];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   _visibilityPollBlock);
}

- (void)startSessionMonitoring {
    [self stopSessionMonitoring];
    _idnowUiWasEverVisible = NO;
    _idnowUiCurrentlyVisible = NO;
    _identificationSessionStarted = NO;

    [self scheduleVisibilityPoll];
    [self schedulePresentationWatchdogWithAttempt:0];
}

- (void)scheduleDismissGracePeriod {
    [self cancelDismissGracePeriod];

    __weak typeof(self) weakSelf = self;
    _dismissGracePeriodBlock = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_result == nil) {
            return;
        }

        if ([strongSelf isIdentificationSessionUiVisible]) {
            strongSelf->_idnowUiCurrentlyVisible = YES;
            strongSelf->_idnowUiWasEverVisible = YES;
            return;
        }

        if (!strongSelf->_idnowUiWasEverVisible && !strongSelf->_identificationSessionStarted) {
            return;
        }

        if ([strongSelf isCameraOrMicrophoneDenied]) {
            [strongSelf completePendingResult:@"idnow_camera_permission_denied"];
        } else {
            [strongSelf completePendingResult:@"idnow_cancelled"];
        }
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   _dismissGracePeriodBlock);
}

- (void)schedulePresentationWatchdogWithAttempt:(NSInteger)attempt {
    if (_identificationSessionStarted) {
        return;
    }

    [self cancelPresentationWatchdog];

    __weak typeof(self) weakSelf = self;
    _presentationWatchdog = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_result == nil || strongSelf->_identificationSessionStarted) {
            return;
        }

        if ([strongSelf isIdentificationSessionUiVisible]) {
            if (attempt < 8) {
                [strongSelf schedulePresentationWatchdogWithAttempt:attempt + 1];
            }
            return;
        }

        if ([strongSelf isCameraOrMicrophonePermissionPending]) {
            if (attempt < 8) {
                [strongSelf schedulePresentationWatchdogWithAttempt:attempt + 1];
            }
            return;
        }

        if ([strongSelf isCameraOrMicrophoneDenied]) {
            [strongSelf completePendingResult:@"idnow_camera_permission_denied"];
            return;
        }

        [strongSelf completePendingResult:@"idnow_presentation_failed"];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   _presentationWatchdog);
}

- (void)completePendingResult:(NSString *)value {
    [self stopSessionMonitoring];

    FlutterResult pendingResult = _result;
    _result = nil;
    if (pendingResult != nil) {
        pendingResult(value);
    }
}

- (void)completePreStartFailure:(NSString *)value {
    [self completePendingResult:value];
}

- (void)completeIdentificationFailureWithError:(NSError *)identificationError
                            canceledByUser:(BOOL)identificationCanceledByUser
                        activeViewController:(UIViewController *)activeViewController {
    if (_identificationSessionStarted || identificationCanceledByUser || _idnowUiWasEverVisible) {
        if ([self isCameraOrMicrophoneDenied]) {
            [self completePendingResult:@"idnow_camera_permission_denied"];
        } else {
            [self completePendingResult:@"idnow_cancelled"];
        }
        return;
    }

    if ([self isCameraOrMicrophoneDenied]) {
        [self completePendingResult:@"idnow_camera_permission_denied"];
        return;
    }

    NSString *message = identificationError.localizedDescription;
    if (message.length == 0) {
        message = @"Identification failed.";
    }
    [self presentFailureAlertOnViewController:activeViewController message:message];
}

- (void)presentFailureAlertOnViewController:(UIViewController *)viewController
                                    message:(NSString *)message {
    if (viewController == nil) {
        [self completePendingResult:@"failed"];
        return;
    }

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error"
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"Ok"
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil];
    [alertController addAction:action];
    [viewController presentViewController:alertController animated:YES completion:nil];

    if (viewController.navigationController != nil) {
        [viewController.navigationController setNavigationBarHidden:YES animated:YES];
    }

    [self completePendingResult:@"failed"];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"startIdentification" isEqualToString:call.method]) {
        _arguments = call.arguments;
        _result = result;

        UIViewController *presentingViewController = [self topViewController];
        if (presentingViewController == nil) {
            [self completePreStartFailure:@"idnow_no_view_controller"];
            return;
        }

        IDnowAppearance *appearance = [IDnowAppearance sharedAppearance];
        appearance.enableStatusBarStyleLightContent = YES;
        appearance.fontNameRegular = @"AmericanTypewriter";
        appearance.fontNameLight = @"AmericanTypewriter-Light";
        appearance.fontNameMedium = @"AmericanTypewriter-CondensedBold";

        NSString *transactionToken = [_arguments objectForKey:@"providerId"];
        NSString *companyID = [_arguments objectForKey:@"providerCompanyId"];
        IDnowSettings *settings;
        if (companyID != nil && companyID.length > 0) {
            settings = [IDnowSettings settingsWithCompanyID:companyID transactionToken:transactionToken];
        } else {
            settings = [IDnowSettings settingsWithTransactionToken:transactionToken];
        }

        IDnowController *idnowController = [[IDnowController alloc] initWithSettings:settings];

        [idnowController initializeWithCompletionBlock:^(BOOL success, NSError *error, BOOL canceledByUser) {
            if (success) {
                UIViewController *activeViewController = [self topViewController] ?: presentingViewController;
                [self startSessionMonitoring];
                [self markIdentificationSessionStartedWithViewController:activeViewController];
                [idnowController startIdentificationFromViewController:activeViewController
                                                   withCompletionBlock:^(BOOL identificationSuccess, NSError *identificationError, BOOL identificationCanceledByUser) {
                    if (identificationSuccess) {
                        [self completePendingResult:@"success"];
                    } else {
                        [self completeIdentificationFailureWithError:identificationError
                                                      canceledByUser:identificationCanceledByUser
                                              activeViewController:activeViewController];
                    }
                }];
            } else if (canceledByUser) {
                [self completePreStartFailure:@"idnow_cancelled"];
            } else if ([self isCameraOrMicrophoneDenied]) {
                [self completePreStartFailure:@"idnow_camera_permission_denied"];
            } else if (error != nil) {
                [self completePreStartFailure:@"idnow_initialize_failed"];
            } else {
                [self completePreStartFailure:@"idnow_initialize_failed"];
            }
        }];
    } else if ([@"removeHeader" isEqualToString:call.method]) {
        UIViewController *viewController = [self topViewController];
        if (viewController.navigationController != nil) {
            [viewController.navigationController setNavigationBarHidden:YES animated:YES];
        }
        result(@"success");
    } else {
        result(FlutterMethodNotImplemented);
    }
}

@end
