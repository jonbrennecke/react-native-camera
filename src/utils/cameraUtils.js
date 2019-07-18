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

export const startCameraPreview = () => {
  CameraManager.startCameraPreview();
};

export const startCameraEffects = async () => {
  const success = await EffectManager.startAsync();
  if (!success) {
    throw new Error('Failed to start camera effects');
  }
};

// TODO:
// stopCameraPreview
// startCameraCapture
// stopCameraCapture
// switchToOppositeCamera

