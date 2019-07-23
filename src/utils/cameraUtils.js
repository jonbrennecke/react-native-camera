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

export const stopCameraPreview = () => {
  CameraManager.stopCameraPreview();
};

export const startCameraEffects = async () => {
  const success = await EffectManager.startAsync();
  if (!success) {
    throw new Error('Failed to start camera effects');
  }
};

export const startCameraCapture = async () => {
  return await CameraManager.startCameraCaptureAsync();
};

export const stopCameraCapture = async ({
  saveToCameraRoll,
}: {
  saveToCameraRoll: boolean,
}): Promise<void> => {
  return await CameraManager.stopCameraCaptureAsync(saveToCameraRoll);
};

export const switchToOppositeCamera = () => {
  CameraManager.switchToOppositeCamera();
};

export const getSupportedISORange = async (): Promise<{
  min: number,
  max: number,
}> => {
  return await CameraManager.getSupportedISORangeAsync();
};

export const getSupportedExposureRange = async (): Promise<{
  min: number,
  max: number,
}> => {
  return await CameraManager.getSupportedExposureRangeAsync();
};

export const setISO = async (iso: number): Promise<void> => {
  return await CameraManager.setISOAsync(iso);
};

export const setExposure = async (exposure: number): Promise<void> => {
  return await CameraManager.setExposureAsync(exposure);
};
