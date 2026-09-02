#if __has_include(<RNTrustbuilderSpec/RNTrustbuilderSpec.h>)
#import <RNTrustbuilderSpec/RNTrustbuilderSpec.h>
#elif __has_include("RNTrustbuilderSpec.h")
#import "RNTrustbuilderSpec.h"
#else
#import <React/RCTBridgeModule.h>
#endif

@interface RNTrustbuilder : NSObject <RCTBridgeModule>

@end
