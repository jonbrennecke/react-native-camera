// @flow
import Bluebird from 'bluebird';
import { NativeModules } from 'react-native';

const { HSCameraManager: NativeCameraManager } = NativeModules;
const CameraManager = Bluebird.promisifyAll(NativeCameraManager);

export const requestCameraPermissions = async (): Promise<boolean> => {
  return CameraManager.requestCameraPermissionsAsync();
}

export const startCameraPreview = () => {
  CameraManager.startCameraPreview();
}


// stopCameraPreview
// startCameraCapture
// stopCameraCapture
// switchToOppositeCamera
