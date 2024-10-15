#import "FlutterIdnowPlugin.h"


#import "IDnowSDK.h"


@implementation FlutterIdnowPlugin {
    FlutterResult _result;
    NSDictionary *_arguments;
    UIViewController *_viewController;
}
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
            methodChannelWithName:@"flutter_idnow"
                  binaryMessenger:[registrar messenger]];

    UIViewController *viewController = [UIApplication sharedApplication].delegate.window.rootViewController;
    FlutterIdnowPlugin* instance = [[FlutterIdnowPlugin alloc] initWithViewController:viewController];
    [registrar addMethodCallDelegate:instance channel:channel];
}


- (instancetype)initWithViewController:(UIViewController *)viewController {
    self = [super init];
    if (self) {
        _viewController = viewController;
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSLog(@"Something To Print");
  if ([@"startIdentification" isEqualToString:call.method]) {
      
      //get arguments
      _arguments = call.arguments;
      _result = result;
      // Setup IDnowAppearance
      IDnowAppearance *appearance = [IDnowAppearance sharedAppearance];

          
      // Adjust statusbar
      appearance.enableStatusBarStyleLightContent = YES;
          
      
      // Adjust fonts
      appearance.fontNameRegular = @"AmericanTypewriter";
      appearance.fontNameLight = @"AmericanTypewriter-Light";
      appearance.fontNameMedium = @"AmericanTypewriter-CondensedBold";

      // To adjust navigation bar / bar button items etc. you should follow Apples UIAppearance protocol.

      // Setup IDnowSettings
      IDnowSettings *settings = [IDnowSettings settingsWithCompanyID:@"expvodenovi"];
      settings.transactionToken =  [_arguments objectForKey:@"providerId"];
      

      // Initialise and start identification
      IDnowController *idnowController = [[IDnowController alloc] initWithSettings: settings];
      
      
      // Initialize identification using blocks
      // (alternatively you can set the delegate and implement the IDnowControllerDelegate protocol)
      [idnowController initializeWithCompletionBlock: ^(BOOL success, NSError *error, BOOL canceledByUser)
      {
              if ( success )
              {
                    // Start identification using blocks
                  [idnowController startIdentificationFromViewController: self->_viewController
                    withCompletionBlock: ^(BOOL success, NSError *error, BOOL canceledByUser)
                    {
                            if ( success )
                            {
                                _result(@"success");
                                // identification was successfull
                            }
                            else
                            {
                                self->_result(@"failed");
                                // identification failed / canceled
                            }
                      }];
              }
              else if ( error )
                     {
                           // Present an alert containing localized error description
                           UIAlertController *alertController = [UIAlertController alertControllerWithTitle: @"Error"
                           message: error.localizedDescription
                           preferredStyle: UIAlertControllerStyleAlert];
                           UIAlertAction *action = [UIAlertAction actionWithTitle: @"Ok"
                           style: UIAlertActionStyleCancel
                           handler: nil];
                           [alertController addAction: action];
                         [self->_viewController presentViewController: alertController animated: true completion: nil];
                         [self->_viewController.navigationController setNavigationBarHidden:YES animated:YES];
                         self->_result(@"failed");
                     }
          }];
  } else {
      [self->_viewController.navigationController setNavigationBarHidden:YES animated:YES];
  }
}
@end
