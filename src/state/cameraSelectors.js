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
