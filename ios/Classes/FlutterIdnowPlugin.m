#import "FlutterIdnowPlugin.h"

#import "IDnowSDK.h"

@implementation FlutterIdnowPlugin {
    FlutterResult _result;
    NSDictionary *_arguments;
    __weak NSObject<FlutterPluginRegistrar> *_registrar;
    dispatch_block_t _presentationWatchdog;
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

- (void)cancelPresentationWatchdog {
    if (_presentationWatchdog != nil) {
        dispatch_block_cancel(_presentationWatchdog);
        _presentationWatchdog = nil;
    }
}

- (void)schedulePresentationWatchdog {
    [self cancelPresentationWatchdog];

    __weak typeof(self) weakSelf = self;
    _presentationWatchdog = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_result == nil) {
            return;
        }

        if ([strongSelf isIdnowUiVisibleFromViewController:[strongSelf topViewController]]) {
            return;
        }

        [strongSelf completePendingResult:@"idnow_presentation_failed"];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   _presentationWatchdog);
}

- (void)completePendingResult:(NSString *)value {
    [self cancelPresentationWatchdog];

    FlutterResult pendingResult = _result;
    _result = nil;
    if (pendingResult != nil) {
        pendingResult(value);
    }
}

- (void)completePreStartFailure:(NSString *)value {
    [self completePendingResult:value];
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
                [self schedulePresentationWatchdog];
                [idnowController startIdentificationFromViewController:activeViewController
                                                   withCompletionBlock:^(BOOL identificationSuccess, NSError *identificationError, BOOL identificationCanceledByUser) {
                    if (identificationSuccess) {
                        [self completePendingResult:@"success"];
                    } else {
                        NSString *message = identificationError.localizedDescription;
                        if (message.length == 0) {
                            message = identificationCanceledByUser
                                ? @"Identification was canceled."
                                : @"Identification failed.";
                        }
                        [self presentFailureAlertOnViewController:activeViewController message:message];
                    }
                }];
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
