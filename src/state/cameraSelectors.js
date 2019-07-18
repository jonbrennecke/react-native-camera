// @flow
import type { ICameraState } from './cameraState';

export const selectCaptureStatus = (state: ICameraState) =>
  state.getCaptureStatus();

export const selectIsCameraStarted = (state: ICameraState) =>
  selectCaptureStatus(state) === 'started';
