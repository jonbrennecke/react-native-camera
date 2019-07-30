// @flow
import { identityActionCreators } from './cameraReducer';
import * as cameraUtils from '../utils/cameraUtils';

import type { Dispatch } from '../types';
import type { CameraFormat } from './cameraState';

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

  loadSupportedFeatures: () => async (dispatch: Dispatch<any>) => {
    await dispatch(actionCreators.loadSupportedISORange());
    await dispatch(actionCreators.loadSupportedExposureRange());
    await dispatch(actionCreators.loadSupportedFormats());
    await dispatch(actionCreators.loadActiveFormat());
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

  loadActiveFormat: () => async (dispatch: Dispatch<*>) => {
    const format = await cameraUtils.getFormat();
    dispatch(actionCreators.setFormat({ format }));
  },

  updateFormat: (format: CameraFormat) => async (dispatch: Dispatch<*>) => {
    dispatch(actionCreators.setFormat({ format }));
    await cameraUtils.setFormat(format);
  },

  loadCameraPermissions: () => async (dispatch: Dispatch<*>) => {
    const hasCameraPermissions = await cameraUtils.hasCameraPermissions();
    dispatch(actionCreators.setHasCameraPermissions({ hasCameraPermissions }));
  },

  requestCameraPermissions: () => async (dispatch: Dispatch<*>) => {
    await cameraUtils.requestCameraPermissions();
    await dispatch(actionCreators.loadCameraPermissions());
  },
};
