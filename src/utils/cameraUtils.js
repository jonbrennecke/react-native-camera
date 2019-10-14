// @flow
import Bluebird from 'bluebird';
import { NativeModules } from 'react-native';

import type { CameraFormat } from '../state';

const { HSCameraManager: NativeCameraManager } = NativeModules;
const CameraManager = Bluebird.promisifyAll(NativeCameraManager);

export const CameraResolutionPresets = {
  hd720p: 'hd720p',
  hd1080p: 'hd1080p',
  hd4K: 'hd4K',
  vga: 'vga',
};

export const requestCameraPermissions = async (): Promise<boolean> => {
  return CameraManager.requestCameraPermissionsAsync();
};

export const hasCameraPermissions = async (): Promise<boolean> => {
  return await CameraManager.hasCameraPermissionsAsync();
};

export type CameraSetupProperties = {
  resolutionPreset: $Keys<typeof CameraResolutionPresets>,
  depthEnabled: boolean,
};

export const startCameraPreview = async (
  properties: $Shape<CameraSetupProperties>
) => {
  await CameraManager.startCameraPreviewAsync(properties);
};

export const stopCameraPreview = () => {
  CameraManager.stopCameraPreview();
};

export const startCameraCapture = async ({
  metadata = {},
}: {
  metadata?: { [key: string]: any },
}) => {
  return await CameraManager.startCameraCaptureAsync(metadata);
};

export const stopCameraCapture = async ({
  saveToCameraRoll,
}: {
  saveToCameraRoll: boolean,
}): Promise<{ url: ?string }> => {
  return await CameraManager.stopCameraCaptureAsync(saveToCameraRoll);
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

// eslint-disable-next-line flowtype/generic-spacing
export const getSupportedFormats = async (): Promise<
  { [key: string]: any }[]
> => {
  return await CameraManager.getSupportedFormatsAsync();
};

export const setFormatWithDepth = async (
  format: CameraFormat,
  depthFormat: CameraFormat
): Promise<void> => {
  return await CameraManager.setFormatAsync(format, depthFormat);
};

export const getFormat = async (): Promise<CameraFormat> => {
  return await CameraManager.getFormatAsync();
};

export const getDepthFormat = async (): Promise<CameraFormat> => {
  return await CameraManager.getDepthFormatAsync();
};

export const getCameraDeviceSupport = async (): Promise<{
  hasSupportedFrontCamera: boolean,
  hasSupportedBackCamera: boolean,
}> => {
  return await CameraManager.getCameraDeviceSupportAsync();
};
