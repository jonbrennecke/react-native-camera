// @flow
import Bluebird from 'bluebird';
import { NativeModules } from 'react-native';

const {
  HSCameraManager: NativeCameraManager,
  HSEffectManager: NativeEffectManager,
} = NativeModules;
const CameraManager = Bluebird.promisifyAll(NativeCameraManager);
const EffectManager = Bluebird.promisifyAll(NativeEffectManager);

export const requestCameraPermissions = async (): Promise<boolean> => {
  return CameraManager.requestCameraPermissionsAsync();
};

export type StartCameraPreviewParams = {
  enableEffects?: boolean,
};

export const startCameraPreview = ({
  enableEffects = false,
}: StartCameraPreviewParams = {}) => {
  CameraManager.startCameraPreview();
  if (enableEffects) {
    EffectManager.startEffects();
  }
};

// TODO:
// stopCameraPreview
// startCameraCapture
// stopCameraCapture
// switchToOppositeCamera
