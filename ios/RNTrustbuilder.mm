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

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(setStorageData:(NSString *)data) {
  [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"trustbuilder_storage_data"];
  [[NSUserDefaults standardUserDefaults] synchronize];
  char *cData = strdup(data.UTF8String);
  int result = IWStorageDataSet(self.iw, cData);
  free(cData);
  return @(result == 0);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(getStorageData) {
  return [[NSUserDefaults standardUserDefaults] stringForKey:@"trustbuilder_storage_data"] ?: @"";
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(storageDataChanged) {
  return @(IWStorageDataChanged(self.iw) > 0);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(isActivated) { return @(IWIsActivated(self.iw) == 1); }
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(isBlocked) { return @(IWIsBlocked(self.iw) == 1); }
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(mustUpgrade) { return @(IWMustUpgrade(self.iw) == 1); }

static NSString *RNTrustbuilderResult(int result) {
  return [NSString stringWithFormat:@"%d", result];
}

static NSString *RNTrustbuilderString(char *value) {
  return value ? [NSString stringWithCString:value encoding:NSISOLatin1StringEncoding] : @"";
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(activationStart:(NSString *)code) {
  char *cCode = strdup(code.UTF8String);
  int result = IWActivationStart(self.iw, cCode);
  free(cCode);
  return RNTrustbuilderResult(result);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(activationFinalize:(NSString *)code pin:(NSString *)pin name:(NSString *)name) {
  char *cCode = strdup(code.UTF8String);
  char *cPin = strdup(pin.UTF8String);
  char *cName = strdup(name.UTF8String);
  int result = IWActivationFinalize(self.iw, cCode, cPin, cName);
  free(cCode); free(cPin); free(cName);
  return RNTrustbuilderResult(result);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(resetStart:(NSString *)code) {
  char *cCode = strdup(code.UTF8String);
  int result = IWResetStart(self.iw, cCode);
  free(cCode);
  return RNTrustbuilderResult(result);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(resetFinalize:(NSString *)code pin:(NSString *)pin) {
  char *cCode = strdup(code.UTF8String);
  char *cPin = strdup(pin.UTF8String);
  int result = IWResetFinalize(self.iw, cCode, cPin);
  free(cCode); free(cPin);
  return RNTrustbuilderResult(result);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(synchronizeStart) { return RNTrustbuilderResult(IWSynchronizeStart(self.iw)); }

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(synchronizeFinalize:(NSString *)pin) {
  char *cPin = strdup(pin.UTF8String);
  int result = IWSynchronizeFinalize(self.iw, cPin);
  free(cPin);
  return RNTrustbuilderResult(result);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(pwdUpdateStart) { return RNTrustbuilderResult(IWPwdUpdateStart(self.iw)); }

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(pwdUpdateFinalize:(NSString *)newPin currentPin:(NSString *)currentPin) {
  char *cNewPin = strdup(newPin.UTF8String);
  char *cCurrentPin = strdup(currentPin.UTF8String);
  int result = IWPwdUpdateFinalize(self.iw, cNewPin, cCurrentPin);
  free(cNewPin); free(cCurrentPin);
  return RNTrustbuilderResult(result);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(setBiokeyStart) { return RNTrustbuilderResult(IWSetBiokeyStart(self.iw)); }

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(setBiokeyFinalize:(NSString *)biokey pin:(NSString *)pin) {
  char *cBiokey = strdup(biokey.UTF8String);
  char *cPin = strdup(pin.UTF8String);
  int result = IWSetBiokeyFinalize(self.iw, cBiokey, cPin);
  free(cBiokey); free(cPin);
  return RNTrustbuilderResult(result);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(unsetBiokeysStart) { return RNTrustbuilderResult(IWUnsetBiokeysStart(self.iw)); }

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(unsetBiokeysFinalize:(NSString *)pin) {
  char *cPin = strdup(pin.UTF8String);
  int result = IWUnsetBiokeysFinalize(self.iw, cPin);
  free(cPin);
  return RNTrustbuilderResult(result);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(onlineOtpStart:(double)serviceIndex) {
  return RNTrustbuilderResult(IWOnlineOtpStart(self.iw, (int)serviceIndex));
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(onlineOtpFinalize:(double)serviceIndex pin:(NSString *)pin keyType:(double)keyType) {
  char *cPin = strdup(pin.UTF8String);
  int result = IWOnlineOtpFinalizeExt(self.iw, (int)serviceIndex, cPin, (int)keyType);
  free(cPin);
  return RNTrustbuilderResult(result);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(otpAnswerOtp) { return RNTrustbuilderString(IWOtpAnswerOtp(self.iw)); }
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(otpShouldSynchronize:(double)serviceId) { return @(IWOtpShouldSynchronize(self.iw, (int)serviceId) == 1); }
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(otpModeQuery:(double)serviceId) { return @(IWOtpModeQuery(self.iw, (int)serviceId) == 1); }

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(otpGenerate:(NSString *)pin) {
  char *cPin = strdup(pin.UTF8String);
  NSString *result = RNTrustbuilderString(IWOtpGenerateMa(self.iw, cPin));
  free(cPin);
  return result;
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(displayTime) { return @(IWDisplayTime(self.iw)); }

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(setDeviceOS:(NSString *)deviceOS) {
  char *cDeviceOS = strdup(deviceOS.UTF8String);
  IWSetDeviceOS(self.iw, cDeviceOS);
  free(cDeviceOS);
  return nil;
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(pushRegistrationStart) { return RNTrustbuilderResult(IWPushRegistrationStart(self.iw)); }

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(pushRegistrationFinalize:(NSString *)pushId) {
  char *cPushId = strdup(pushId.UTF8String);
  int result = IWPushRegistrationFinalize(self.iw, cPushId);
  free(cPushId);
  return RNTrustbuilderResult(result);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(checkPush) { return RNTrustbuilderResult(IWCheckPush(self.iw)); }
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(pushAlias) { return RNTrustbuilderString(IWPushAlias(self.iw)); }
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(pushAction) { return RNTrustbuilderString(IWPushAction(self.iw)); }
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(pushContext) { return RNTrustbuilderString(IWPushContext(self.iw)); }

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(onlineSealStart:(double)serviceIndex) {
  return RNTrustbuilderResult(IWOnlineSealStart(self.iw, (int)serviceIndex));
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(onlineSealFinalize:(double)serviceIndex pin:(NSString *)pin keyType:(double)keyType sealData:(NSString *)sealData) {
  char *cPin = strdup(pin.UTF8String);
  char *cSealData = strdup(sealData.UTF8String);
  int result = IWOnlineSealFinalizeExt(self.iw, (int)serviceIndex, cPin, (int)keyType, cSealData);
  free(cPin); free(cSealData);
  return RNTrustbuilderResult(result);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(sealAnswerOtp) { return RNTrustbuilderString(IWSealAnswerOtp(self.iw)); }
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(sealShouldSynchronize:(double)serviceId) { return @(IWSealShouldSynchronize(self.iw, (int)serviceId) == 1); }
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(sealModeQuery:(double)serviceId) { return @(IWSealModeQuery(self.iw, (int)serviceId) == 1); }

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(sealGenerate:(NSString *)pin sealData:(NSString *)sealData) {
  char *cPin = strdup(pin.UTF8String);
  char *cSealData = strdup(sealData.UTF8String);
  NSString *result = RNTrustbuilderString(IWSealGenerate(self.iw, cPin, cSealData));
  free(cPin); free(cSealData);
  return result;
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(serviceNb) { return @(IWServiceNb(self.iw)); }
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(serviceName:(double)index) { return RNTrustbuilderString(IWServiceName(self.iw, (int)index)); }
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(serviceLogo:(double)index) { return RNTrustbuilderString(IWServiceLogo(self.iw, (int)index)); }
RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(serviceDisabled:(double)index) { return @(IWServiceDisabled(self.iw, (int)index) == 1); }

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(getVersionInfo) {
  NSDictionary *result = @{
    @"libraryVersion": RNTrustbuilderString(IWVersionGet(self.iw)),
    @"newVersionAvailable": RNTrustbuilderString(IWNewVersionAvailable(self.iw)),
    @"newVersionUrl": RNTrustbuilderString(IWNewVersionURL(self.iw)),
    @"majorVersionRequired": @(IWMajorVersionRequired(self.iw) == 1),
    @"shouldAskForMinorUpdate": @(IWShouldAskForMinorUpdate(self.iw) == 1)
  };
  NSData *resultData = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
  return [[NSString alloc] initWithData:resultData encoding:NSUTF8StringEncoding];
}

- (NSArray<NSString *> *)supportedEvents {
  return @[@"TrustbuilderPushEvent"];
}

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

@end

