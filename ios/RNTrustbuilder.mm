#import "RNTrustbuilder.h"
extern "C" {
#import "iw.h"
}
#import <React/RCTEventEmitter.h>

@interface RNTrustbuilder () <RCTBridgeModule>
@property (nonatomic, assign) IW *iw;
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, strong) NSCondition *webCallCondition;
@property (nonatomic, strong) NSString *webCallResult;
@end

// Static C function matching WEBSERVICECALL signature
static int RNTrustbuilderWebServiceCall(char *url, int timeoutMs, void *user) {
    RNTrustbuilder *self = (__bridge RNTrustbuilder *)user;
    if (!self) return 0;

    NSString *urlStr = [NSString stringWithCString:url encoding:NSISOLatin1StringEncoding];
    NSURL *nsUrl = [NSURL URLWithString:urlStr];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:nsUrl
                                                  cachePolicy:NSURLRequestUseProtocolCachePolicy
                                              timeoutInterval:timeoutMs / 1000.0];

    __block BOOL completed = NO;

    [[[NSURLSession sharedSession] dataTaskWithRequest:request
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *err) {
        if (data && !err) {
            const char *bytes = (const char *)[data bytes];
            char *buffer = (char *)malloc([data length] + 1);
            memcpy(buffer, bytes, [data length]);
            buffer[[data length]] = '\0';

            IWSetWsBuffer(self.iw, buffer);
            free(buffer);
        }

        [self.webCallCondition lock];
        completed = YES;
        [self.webCallCondition signal];
        [self.webCallCondition unlock];
    }] resume];

    [self.webCallCondition lock];
    while (!completed) {
        [self.webCallCondition wait];
    }
    [self.webCallCondition unlock];
    return 0;
}

@implementation RNTrustbuilder

RCT_EXPORT_MODULE(RNTrustbuilder)

- (instancetype)init {
  self = [super init];
  if (self) {
    _webCallCondition = [[NSCondition alloc] init];
    _isInitialized = NO;
  }
  return self;
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(initialize:(NSString *)config)
{
  NSError *error = nil;
  NSData *configData = [config dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *configDict = [NSJSONSerialization JSONObjectWithData:configData options:0 error:&error];
  if (error || ![configDict isKindOfClass:[NSDictionary class]]) {
    return @"{\"isActivated\":false,\"isBlocked\":false}";
  }

  NSString *macId = configDict[@"macId"] ?: @"";
  NSString *server = configDict[@"server"] ?: @"https://www.myinwebo.com";
  NSString *hostVersion = configDict[@"hostVersion"] ?: @"react-native-mfa-trustbuilder-0.1.0";
  NSInteger timeout = [configDict[@"timeout"] integerValue] ?: 60000;
  NSString *lang = configDict[@"lang"] ?: @"1";
  NSString *serialNumber = [UIDevice currentDevice].identifierForVendor.UUIDString ?: @"";

  char *cSerialNumber = strdup(serialNumber.UTF8String);
  char *cAppData = strdup("_");
  __weak RNTrustbuilder *weakSelf = self;

  self.iw = IWInit(0, cSerialNumber, cAppData, RNTrustbuilderWebServiceCall, (__bridge void *)self);

  free(cSerialNumber);
  free(cAppData);
  IWHostVersionSet(self.iw, strdup(hostVersion.UTF8String));
  IWWsServerSet(self.iw, strdup(server.UTF8String));
  IWWsTimeoutSet(self.iw, (int)timeout);
  IWMaccessSet(self.iw, strdup(macId.UTF8String));
  IWSetLang(self.iw, strdup(lang.UTF8String));

  NSString *storedData = [[NSUserDefaults standardUserDefaults] stringForKey:@"trustbuilder_storage_data"] ?: @"";
  char *cStoredData = strdup(storedData.UTF8String);
  IWStorageDataSet(self.iw, cStoredData);
  free(cStoredData);
  self.isInitialized = YES;

  NSDictionary *result = @{
    @"isActivated": @(IWIsActivated(self.iw) == 1),
    @"isBlocked": @(IWIsBlocked(self.iw) == 1)
  };
  NSData *resultData = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
  return [[NSString alloc] initWithData:resultData encoding:NSUTF8StringEncoding];
}

// ... (rest of your methods remain unchanged) ...

- (NSArray<NSString *> *)supportedEvents {
  return @[@"TrustbuilderPushEvent"];
}

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

@end

