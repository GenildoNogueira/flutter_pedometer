#import "FlutterPedometerPlugin.h"
#if __has_include(<flutter_pedometer/flutter_pedometer-Swift.h>)
#import <flutter_pedometer/flutter_pedometer-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_pedometer-Swift.h"
#endif

@implementation FlutterPedometerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  [SwiftPedometerPlugin registerWithRegistrar:registrar];
}
@end
