// @flow
import { createReducer } from './createReducer';
import { createCameraState } from './cameraState';
import * as cameraUtils from '../utils/cameraUtils';

import type { Action, Dispatch } from '../types';
import type {
  ICameraState,
  CameraCaptureStatus,
  CameraISORange,
  CameraExposureRange,
  CameraFormat,
} from './cameraState';

const CameraState = createCameraState({
  captureStatus: 'stopped',
  supportedISORange: { min: 0, max: 16000 },
  supportedExposureRange: { min: 0, max: 16000 },
  supportedFormats: [],
  iso: 0,
  exposure: 0,
});

export const initialState = new CameraState();

const reducers = {
  setCaptureStatus: (
    state,
    { payload }: Action<{ captureStatus: CameraCaptureStatus }>
  ): ICameraState => {
    if (!payload) {
      return state;
    }
    return state.setCaptureStatus(payload.captureStatus);
  },

  setSupportedISORange: (
    state,
    { payload }: Action<{ range: CameraISORange }>
  ): ICameraState => {
    if (!payload) {
      return state;
    }
    return state.setSupportedISORange(payload.range);
  },

  setSupportedExposureRange: (
    state,
    { payload }: Action<{ range: CameraExposureRange }>
  ): ICameraState => {
    if (!payload) {
      return state;
    }
    return state.setSupportedExposureRange(payload.range);
  },

  setSupportedFormats: (
    state,
    { payload }: Action<{ formats: CameraFormat[] }>
  ): ICameraState => {
    if (!payload) {
      return state;
    }
    return state.setSupportedFormats(payload.formats);
  },

  setISO: (state, { payload }: Action<{ iso: number }>): ICameraState => {
    if (!payload) {
      return state;
    }
    return state.setISO(payload.iso);
  },

  setExposure: (
    state,
    { payload }: Action<{ exposure: number }>
  ): ICameraState => {
    if (!payload) {
      return state;
    }
    return state.setExposure(payload.exposure);
  },
};

export const {
  reducer,
  actionCreators: identityActionCreators,
} = createReducer(initialState, reducers);

export const actionCreators = {
  ...identityActionCreators,

  startCapture: () => async (dispatch: Dispatch<*>) => {
    await cameraUtils.startCameraCapture();
    dispatch(actionCreators.setCaptureStatus({ captureStatus: 'started' }));
  },

  stopCapture: ({
    saveToCameraRoll = false,
  }: {
    saveToCameraRoll: boolean,
  }) => async (dispatch: Dispatch<*>) => {
    await cameraUtils.stopCameraCapture({ saveToCameraRoll });
    dispatch(actionCreators.setCaptureStatus({ captureStatus: 'stopped' }));
  },

  loadSupportedISORange: () => async (dispatch: Dispatch<*>) => {
    const range = await cameraUtils.getSupportedISORange();
    dispatch(actionCreators.setSupportedISORange({ range }));
  },

  loadSupportedExposureRange: () => async (dispatch: Dispatch<*>) => {
    const range = await cameraUtils.getSupportedExposureRange();
    dispatch(actionCreators.setSupportedExposureRange({ range }));
  },

  loadSupportedFeatures: () => async (dispatch: Dispatch<*>) => {
    await dispatch(actionCreators.loadSupportedISORange());
    await dispatch(actionCreators.loadSupportedExposureRange());
    await dispatch(actionCreators.loadSupportedFormats());
  },

  updateISO: (iso: number) => async (dispatch: Dispatch<*>) => {
    await cameraUtils.setISO(iso);
    dispatch(actionCreators.setISO({ iso }));
  },

  updateExposure: (exposure: number) => async (dispatch: Dispatch<*>) => {
    await cameraUtils.setExposure(exposure);
    dispatch(actionCreators.setExposure({ exposure }));
  },

  loadSupportedFormats: () => async (dispatch: Dispatch<any>) => {
    const formats = await cameraUtils.getSupportedFormats();
    dispatch(actionCreators.setSupportedFormats({ formats }));
  },
};
