// @flow
import { createReducer } from './createReducer';
import { createCameraState } from './cameraState';
import { Map } from 'immutable';

import type { Action } from '../types';
import type {
  ICameraState,
  CameraCaptureStatus,
  CameraISORange,
  CameraExposureRange,
  CameraFormat,
  CameraDeviceSupportObject,
  PlaybackState,
} from './cameraState';

const CameraState = createCameraState({
  captureStatus: 'stopped',
  supportedISORange: { min: 0, max: 16000 },
  supportedExposureRange: { min: 0, max: 16000 },
  supportedFormats: [],
  blurAperture: 0,
  iso: 0,
  exposure: 0,
  format: null,
  depthFormat: null,
  hasCameraPermissions: false,
  playbackState: 'waiting',
  playbackProgress: 0,
  lastCapturedVideoURL: null,
  cameraDeviceSupport: null,
  playbackStateMap: Map({}),
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

  setLastCapturedVideoURL: (
    state,
    { payload }: Action<{ url: ?string }>
  ): ICameraState => {
    if (!payload) {
      return state;
    }
    return state.setLastCapturedVideoURL(payload.url);
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

  setHasCameraPermissions: (
    state,
    { payload }: Action<{ hasCameraPermissions: boolean }>
  ): ICameraState => {
    if (!payload) {
      return state;
    }
    return state.setHasCameraPermissions(payload.hasCameraPermissions);
  },

  setFormat: (
    state,
    { payload }: Action<{ format: CameraFormat }>
  ): ICameraState => {
    if (!payload) {
      return state;
    }
    return state.setFormat(payload.format);
  },

  setDepthFormat: (
    state,
    { payload }: Action<{ depthFormat: CameraFormat }>
  ): ICameraState => {
    if (!payload) {
      return state;
    }
    return state.setDepthFormat(payload.depthFormat);
  },

  setBlurAperture: (
    state,
    { payload }: Action<{ blurAperture: number }>
  ): ICameraState => {
    if (!payload) {
      return state;
    }
    return state.setBlurAperture(payload.blurAperture);
  },

  setPlaybackState: (
    state,
    { payload }: Action<{ assetID: string, playbackState: PlaybackState }>
  ): ICameraState => {
    if (!payload) {
      return state;
    }
    return state.setPlaybackState(payload.assetID, payload.playbackState);
  },

  setPlaybackProgress: (
    state,
    { payload }: Action<{ playbackProgress: number }>
  ): ICameraState => {
    if (!payload) {
      return state;
    }
    return state.setPlaybackProgress(payload.playbackProgress);
  },

  setCameraDeviceSupport: (
    state,
    { payload }: Action<{ cameraDeviceSupport: CameraDeviceSupportObject }>
  ): ICameraState => {
    if (!payload) {
      return state;
    }
    return state.setCameraDeviceSupport(payload.cameraDeviceSupport);
  },
};

export const {
  reducer,
  actionCreators: identityActionCreators,
} = createReducer(initialState, reducers);
