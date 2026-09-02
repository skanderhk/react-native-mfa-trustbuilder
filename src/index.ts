import { NativeModules, NativeEventEmitter, Platform } from 'react-native';
import type { Spec } from './NativeRNTrustbuilder';
import { TrustbuilderError, TrustbuilderErrorCode, assertOk } from './errors';
import type {
  InitConfig,
  InitResult,
  ServiceInfo,
  PushInfo,
  OtpResult,
  SealResult,
  VersionInfo,
  PinMode,
  PinModeResult,
  KeyType,
  PushAction,
} from './types';

const LINKING_ERROR =
  `The package 'react-native-mfa-trustbuilder' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo managed workflow\n';

function resolveNativeModule(name: string): any {
  if (NativeModules && (NativeModules as any)[name])
    return (NativeModules as any)[name];
  try {
    const {
      TurboModuleRegistry,
    } = require('react-native/Libraries/TurboModule/TurboModuleRegistry');
    if (TurboModuleRegistry && TurboModuleRegistry.get) {
      const tm = TurboModuleRegistry.get(name);
      if (tm) return tm;
    }
  } catch (e) {
    console.error('Error while trying to resolve native module:', e);
    // ignore
  }
  if (
    typeof globalThis !== 'undefined' &&
    (globalThis as any).__turboModuleProxy &&
    (globalThis as any).__turboModuleProxy[name]
  ) {
    return (globalThis as any).__turboModuleProxy[name];
  }
  return null;
}

const RNTrustbuilder = (
  resolveNativeModule('RNTrustbuilder')
    ? resolveNativeModule('RNTrustbuilder')
    : new Proxy(
        {},
        {
          get() {
            throw new Error(LINKING_ERROR);
          },
        }
      )
) as Spec;

const EVENT_NAME = 'TrustbuilderPushEvent';

function pinModeFromCode(code: number): PinMode {
  switch (code) {
    case 0:
      return 'none';
    case 1:
      return 'current';
    case 2:
      return 'new';
    case 8:
      return 'bio';
    case 9:
      return 'currentOrBio';
    default:
      return 'none';
  }
}

function pinModeToResult(code: number): PinModeResult {
  return {
    pinMode: pinModeFromCode(code),
    // eslint-disable-next-line no-bitwise
    requiresPin: (code & 1) === 1,
    // eslint-disable-next-line no-bitwise
    requiresBio: (code & 8) === 8,
  };
}

function keyTypeToNumber(keyType: KeyType): number {
  return keyType === 'biokey' ? 1 : 0;
}

class Trustbuilder {
  private _initialized = false;
  private _eventEmitter: NativeEventEmitter | null = null;

  get isInitialized(): boolean {
    return this._initialized;
  }

  initialize(config: InitConfig): InitResult {
    const configStr = JSON.stringify({
      macId: config.macId,
      server: config.server || 'https://www.myinwebo.com',
      hostVersion: config.hostVersion || 'react-native-mfa-trustbuilder-0.1.0',
      timeout: config.timeout || 60000,
      lang: config.lang === 'fr' ? '2' : '1',
    });

    const resultStr = RNTrustbuilder.initialize(configStr);
    const result = JSON.parse(resultStr) as InitResult;
    this._initialized = true;
    return result;
  }

  setStorageData(data: string): void {
    RNTrustbuilder.setStorageData(data);
  }

  getStorageData(): string {
    return RNTrustbuilder.getStorageData();
  }

  storageDataChanged(): boolean {
    return RNTrustbuilder.storageDataChanged();
  }

  saveStorageIfNeeded(): void {
    if (this.storageDataChanged()) {
      const data = this.getStorageData();
      this.setStorageData(data);
    }
  }

  isActivated(): boolean {
    return RNTrustbuilder.isActivated();
  }

  isBlocked(): boolean {
    return RNTrustbuilder.isBlocked();
  }

  mustUpgrade(): boolean {
    return RNTrustbuilder.mustUpgrade();
  }

  async activationStart(code: string): Promise<void> {
    const result = parseInt(RNTrustbuilder.activationStart(code), 10);
    assertOk(result);
  }

  async activationFinalize(
    code: string,
    pin: string,
    name: string
  ): Promise<void> {
    const result = parseInt(
      RNTrustbuilder.activationFinalize(code, pin, name),
      10
    );
    assertOk(result);
  }

  async activate(code: string, pin: string, name: string): Promise<void> {
    await this.activationStart(code);
    await this.activationFinalize(code, pin, name);
  }

  async resetStart(code: string): Promise<void> {
    const result = parseInt(RNTrustbuilder.resetStart(code), 10);
    assertOk(result);
  }

  async resetFinalize(code: string, pin: string): Promise<void> {
    const result = parseInt(RNTrustbuilder.resetFinalize(code, pin), 10);
    assertOk(result);
  }

  async reset(code: string, pin: string): Promise<void> {
    await this.resetStart(code);
    await this.resetFinalize(code, pin);
  }

  async synchronizeStart(): Promise<void> {
    const result = parseInt(RNTrustbuilder.synchronizeStart(), 10);
    assertOk(result);
  }

  async synchronizeFinalize(pin: string): Promise<void> {
    const result = parseInt(RNTrustbuilder.synchronizeFinalize(pin), 10);
    assertOk(result);
  }

  async synchronize(pin: string): Promise<void> {
    await this.synchronizeStart();
    await this.synchronizeFinalize(pin);
  }

  async pwdUpdateStart(): Promise<void> {
    const result = parseInt(RNTrustbuilder.pwdUpdateStart(), 10);
    assertOk(result);
  }

  async pwdUpdateFinalize(newPin: string, currentPin: string): Promise<void> {
    const result = parseInt(
      RNTrustbuilder.pwdUpdateFinalize(newPin, currentPin),
      10
    );
    assertOk(result);
  }

  async updatePin(newPin: string, currentPin: string): Promise<void> {
    await this.pwdUpdateStart();
    await this.pwdUpdateFinalize(newPin, currentPin);
  }

  async setBiokeyStart(): Promise<void> {
    const result = parseInt(RNTrustbuilder.setBiokeyStart(), 10);
    assertOk(result);
  }

  async setBiokeyFinalize(biokey: string, pin: string): Promise<void> {
    const result = parseInt(RNTrustbuilder.setBiokeyFinalize(biokey, pin), 10);
    assertOk(result);
  }

  async registerBiokey(biokey: string, pin: string): Promise<void> {
    await this.setBiokeyStart();
    await this.setBiokeyFinalize(biokey, pin);
  }

  async unsetBiokeysStart(): Promise<void> {
    const result = parseInt(RNTrustbuilder.unsetBiokeysStart(), 10);
    assertOk(result);
  }

  async unsetBiokeysFinalize(pin: string): Promise<void> {
    const result = parseInt(RNTrustbuilder.unsetBiokeysFinalize(pin), 10);
    assertOk(result);
  }

  async resetBiokeys(pin: string): Promise<void> {
    await this.unsetBiokeysStart();
    await this.unsetBiokeysFinalize(pin);
  }

  async onlineOtpStart(serviceIndex = 0): Promise<void> {
    const result = parseInt(RNTrustbuilder.onlineOtpStart(serviceIndex), 10);
    assertOk(result);
  }

  async onlineOtpFinalize(
    serviceIndex: number,
    pin: string,
    keyType: KeyType = 'pin'
  ): Promise<void> {
    const result = parseInt(
      RNTrustbuilder.onlineOtpFinalize(
        serviceIndex,
        pin,
        keyTypeToNumber(keyType)
      ),
      10
    );
    assertOk(result);
  }

  getOtp(): string {
    return RNTrustbuilder.otpAnswerOtp();
  }

  async generateOnlineOtp(
    pin: string,
    serviceIndex = 0,
    keyType: KeyType = 'pin'
  ): Promise<OtpResult> {
    await this.onlineOtpStart(serviceIndex);
    await this.onlineOtpFinalize(serviceIndex, pin, keyType);
    const otp = this.getOtp();
    const remainingTime = this.displayTime();
    return { otp, remainingTime };
  }

  otpShouldSynchronize(serviceId = 0): boolean {
    return RNTrustbuilder.otpShouldSynchronize(serviceId);
  }

  otpModeQuery(serviceId = 0): boolean {
    return RNTrustbuilder.otpModeQuery(serviceId);
  }

  otpGenerate(pin: string): string {
    return RNTrustbuilder.otpGenerate(pin);
  }

  displayTime(): number {
    return RNTrustbuilder.displayTime();
  }

  async generateOfflineOtp(pin: string, serviceId = 0): Promise<OtpResult> {
    if (this.otpShouldSynchronize(serviceId)) {
      throw new TrustbuilderError(
        TrustbuilderErrorCode.SYNCHROFAILED,
        'Synchronization required before offline OTP generation'
      );
    }
    const requiresPin = this.otpModeQuery(serviceId);
    const otp = this.otpGenerate(requiresPin ? pin : '');
    const remainingTime = this.displayTime();
    return { otp, remainingTime };
  }

  setDeviceOS(deviceOS: string): void {
    RNTrustbuilder.setDeviceOS(deviceOS);
  }

  async pushRegistrationStart(): Promise<void> {
    const result = parseInt(RNTrustbuilder.pushRegistrationStart(), 10);
    assertOk(result);
  }

  async pushRegistrationFinalize(pushId: string): Promise<void> {
    const result = parseInt(
      RNTrustbuilder.pushRegistrationFinalize(pushId),
      10
    );
    assertOk(result);
  }

  async registerForPush(pushId: string): Promise<void> {
    await this.pushRegistrationStart();
    await this.pushRegistrationFinalize(pushId);
  }

  checkPush(): number {
    return parseInt(RNTrustbuilder.checkPush(), 10);
  }

  getPushInfo(): PushInfo | null {
    const code = this.checkPush();
    if (code === 0) {
      return {
        alias: RNTrustbuilder.pushAlias(),
        action: RNTrustbuilder.pushAction() as PushAction,
        context: RNTrustbuilder.pushContext(),
      };
    }
    return null;
  }

  async onlineSealStart(serviceIndex = 0): Promise<void> {
    const result = parseInt(RNTrustbuilder.onlineSealStart(serviceIndex), 10);
    assertOk(result);
  }

  async onlineSealFinalize(
    serviceIndex: number,
    pin: string,
    keyType: KeyType,
    sealData: string
  ): Promise<void> {
    const result = parseInt(
      RNTrustbuilder.onlineSealFinalize(
        serviceIndex,
        pin,
        keyTypeToNumber(keyType),
        sealData
      ),
      10
    );
    assertOk(result);
  }

  getSeal(): string {
    return RNTrustbuilder.sealAnswerOtp();
  }

  async generateOnlineSeal(
    pin: string,
    sealData: string,
    serviceIndex = 0,
    keyType: KeyType = 'pin'
  ): Promise<SealResult> {
    await this.onlineSealStart(serviceIndex);
    await this.onlineSealFinalize(serviceIndex, pin, keyType, sealData);
    return { seal: this.getSeal() };
  }

  sealShouldSynchronize(serviceId = 0): boolean {
    return RNTrustbuilder.sealShouldSynchronize(serviceId);
  }

  sealModeQuery(serviceId = 0): boolean {
    return RNTrustbuilder.sealModeQuery(serviceId);
  }

  sealGenerate(pin: string, sealData: string): string {
    return RNTrustbuilder.sealGenerate(pin, sealData);
  }

  async generateOfflineSeal(
    pin: string,
    sealData: string,
    serviceId = 0
  ): Promise<SealResult> {
    if (this.sealShouldSynchronize(serviceId)) {
      throw new TrustbuilderError(
        TrustbuilderErrorCode.SYNCHROFAILED,
        'Synchronization required before offline seal generation'
      );
    }
    this.sealModeQuery(serviceId);
    return { seal: this.sealGenerate(pin, sealData) };
  }

  serviceNb(): number {
    return RNTrustbuilder.serviceNb();
  }

  getServiceName(index = 0): string {
    return RNTrustbuilder.serviceName(index);
  }

  getServiceLogo(index = 0): string {
    return RNTrustbuilder.serviceLogo(index);
  }

  isServiceDisabled(index = 0): boolean {
    return RNTrustbuilder.serviceDisabled(index);
  }

  getServiceInfo(index = 0): ServiceInfo {
    return {
      name: this.getServiceName(index),
      logoUrl: this.getServiceLogo(index),
      isDisabled: this.isServiceDisabled(index),
    };
  }

  getVersionInfo(): VersionInfo {
    const resultStr = RNTrustbuilder.getVersionInfo();
    return JSON.parse(resultStr) as VersionInfo;
  }

  getPinMode(): PinModeResult {
    const code = parseInt(RNTrustbuilder.serviceName(0), 10);
    return pinModeToResult(code);
  }

  private _setupEventEmitter(): void {
    if (this._eventEmitter) return;
    this._eventEmitter = new NativeEventEmitter(
      NativeModules.RNTrustbuilder as any
    );
  }

  onPushReceived(listener: (pushInfo: PushInfo) => void): () => void {
    this._setupEventEmitter();
    const subscription = this._eventEmitter!.addListener(
      EVENT_NAME,
      (data: PushInfo) => {
        listener(data);
      }
    );
    return () => subscription.remove();
  }
}

export const trustbuilder = new Trustbuilder();

export { TrustbuilderError, TrustbuilderErrorCode } from './errors';
export type {
  InitConfig,
  InitResult,
  ServiceInfo,
  PushInfo,
  OtpResult,
  SealResult,
  VersionInfo,
  PinMode,
  PinModeResult,
  KeyType,
  PushAction,
} from './types';
