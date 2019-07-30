// @flow
import type { ICameraState } from './cameraState';

export const selectCaptureStatus = (state: ICameraState) =>
  state.getCaptureStatus();

export const selectIsCameraStarted = (state: ICameraState) =>
  selectCaptureStatus(state) === 'started';

export const selectSupportedISORange = (state: ICameraState) =>
  state.getSupportedISORange();

export const selectSupportedExposureRange = (state: ICameraState) =>
  state.getSupportedExposureRange();

export const selectISO = (state: ICameraState) => state.getISO();

export const selectExposure = (state: ICameraState) => state.getExposure();

export const selectSupportedFormats = (state: ICameraState) =>
  state.getSupportedFormats();

export const selectHasCameraPermissions = (state: ICameraState) =>
  state.hasCameraPermissions();

export const selectFormat = (state: ICameraState) => state.getFormat();
