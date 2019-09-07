// @flow
import { identityActionCreators } from './cameraReducer';
import * as cameraUtils from '../utils/cameraUtils';

import type { Dispatch } from '../types';
import type { CameraFormat } from './cameraState';

export const actionCreators = {
  ...identityActionCreators,

  startCapture: ({ metadata }: { metadata?: { [key: string]: any } }) => async (
    dispatch: Dispatch<*>
  ) => {
    await cameraUtils.startCameraCapture({ metadata });
    dispatch(actionCreators.setCaptureStatus({ captureStatus: 'started' }));
  },

  stopCapture: ({
    saveToCameraRoll = false,
  }: {
    saveToCameraRoll: boolean,
  }) => async (dispatch: Dispatch<any>) => {
    const { url } = await cameraUtils.stopCameraCapture({
      saveToCameraRoll,
    });
    url && dispatch(actionCreators.setLastCapturedVideoURL({ url }));
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
    await dispatch(actionCreators.loadCameraDeviceSupport());
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

  loadCameraDeviceSupport: () => async (dispatch: Dispatch<*>) => {
    const cameraDeviceSupport = await cameraUtils.getCameraDeviceSupport();
    dispatch(actionCreators.setCameraDeviceSupport({ cameraDeviceSupport }));
  },

  updateFormat: (format: CameraFormat, depthFormat: CameraFormat) => async (
    dispatch: Dispatch<any>
  ) => {
    dispatch(actionCreators.setFormat({ format }));
    dispatch(actionCreators.setDepthFormat({ depthFormat }));
    await cameraUtils.setFormatWithDepth(format, depthFormat);
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
