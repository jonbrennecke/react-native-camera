// @flow
import React from 'react';
import { connect } from 'react-redux';
import identity from 'lodash/identity';

import { actionCreators } from './cameraActionCreators';
import * as selectors from './cameraSelectors';

import type { ComponentType } from 'react';

import type { Dispatch } from '../types';
import type {
  ICameraState,
  CameraCaptureStatus,
  CameraISORange,
  CameraExposureRange,
  CameraFormat,
  CameraDeviceSupportObject,
  PlaybackState,
} from './';

type OwnProps = {};

type StateProps = {
  captureStatus: CameraCaptureStatus,
  supportedISORange: CameraISORange,
  supportedExposureRange: CameraExposureRange,
  supportedFormats: CameraFormat[],
  blurAperture: number,
  iso: number,
  exposure: number,
  format: ?CameraFormat,
  depthFormat: ?CameraFormat,
  hasCameraPermissions: boolean,
  playbackState: PlaybackState,
  playbackProgress: number,
  lastCapturedVideoURL: ?string,
  cameraDeviceSupport: ?CameraDeviceSupportObject,
};

type DispatchProps = {
  startCapture: ({
    metadata?: { [key: string]: any },
  }) => any,
  stopCapture: ({
    saveToCameraRoll: boolean,
  }) => any,
  loadSupportedFeatures: () => any,
  updateISO: (iso: number) => any,
  updateExposure: (exposure: number) => any,
  updateFormat: (format: CameraFormat, depthFormat: CameraFormat) => any,
  loadCameraPermissions: () => any,
  requestCameraPermissions: () => any,
  setBlurAperture: (blurAperture: number) => any,
  setPlaybackState: (playbackState: PlaybackState) => any,
  setPlaybackProgress: (playbackProgress: number) => any,
};

export type CameraStateHOCProps = OwnProps & StateProps & DispatchProps;

function mapCameraStateToProps(state: ICameraState): $Exact<StateProps> {
  return {
    captureStatus: selectors.selectCaptureStatus(state),
    supportedISORange: selectors.selectSupportedISORange(state),
    supportedExposureRange: selectors.selectSupportedExposureRange(state),
    supportedFormats: selectors.selectSupportedFormats(state),
    iso: selectors.selectISO(state),
    exposure: selectors.selectExposure(state),
    format: selectors.selectFormat(state),
    depthFormat: selectors.selectDepthFormat(state),
    blurAperture: selectors.selectBlurAperture(state),
    hasCameraPermissions: selectors.selectHasCameraPermissions(state),
    playbackState: selectors.selectPlaybackState(state),
    playbackProgress: selectors.selectPlaybackProgress(state),
    lastCapturedVideoURL: selectors.selectLastCapturedVideoURL(state),
    cameraDeviceSupport: selectors.selectCameraDeviceSupport(state),
  };
}

function mapCameraDispatchToProps(
  dispatch: Dispatch<any>
): $Exact<DispatchProps> {
  return {
    startCapture: (args: { metadata?: { [key: string]: any } }) =>
      dispatch(actionCreators.startCapture(args)),
    stopCapture: (args: { saveToCameraRoll: boolean }) =>
      dispatch(actionCreators.stopCapture(args)),
    loadSupportedFeatures: () =>
      dispatch(actionCreators.loadSupportedFeatures()),
    updateISO: (iso: number) => dispatch(actionCreators.updateISO(iso)),
    updateExposure: (exposure: number) =>
      dispatch(actionCreators.updateExposure(exposure)),
    updateFormat: (format: CameraFormat, depthFormat: CameraFormat) =>
      dispatch(actionCreators.updateFormat(format, depthFormat)),
    loadCameraPermissions: () =>
      dispatch(actionCreators.loadCameraPermissions()),
    requestCameraPermissions: () =>
      dispatch(actionCreators.requestCameraPermissions()),
    setBlurAperture: (blurAperture: number) =>
      dispatch(actionCreators.setBlurAperture({ blurAperture })),
    setPlaybackState: (playbackState: PlaybackState) =>
      dispatch(actionCreators.setPlaybackState({ playbackState })),
    setPlaybackProgress: (playbackProgress: number) =>
      dispatch(actionCreators.setPlaybackProgress({ playbackProgress })),
  };
}

const createSlicedStateToPropsMapper = <State, StateSlice, StateProps>(
  mapStateToProps: StateSlice => StateProps,
  stateSliceAccessor?: State => StateSlice = identity
): ((state: State) => StateProps) => {
  return state => {
    const stateSlice = stateSliceAccessor(state);
    return mapStateToProps(stateSlice);
  };
};

const createSlicedDispatchToPropsMapper = <State, StateSlice, DispatchProps>(
  mapDispatchToProps: (Dispatch<*>, () => StateSlice) => DispatchProps,
  stateSliceAccessor?: State => StateSlice = identity
): ((dispatch: Dispatch<*>, getState: () => State) => DispatchProps) => {
  return (dispatch, getState) => {
    const getSlicedSlice = () => stateSliceAccessor(getState());
    return mapDispatchToProps(dispatch, getSlicedSlice);
  };
};

export type CameraStateHOC<OriginalProps> = (
  Component: ComponentType<CameraStateHOCProps & OriginalProps>
) => ComponentType<OriginalProps>;

export function createCameraStateHOC<PassThroughProps, State: ICameraState>(
  stateSliceAccessor?: State => ICameraState = identity
): CameraStateHOC<PassThroughProps> {
  const mapStateToProps = createSlicedStateToPropsMapper(
    mapCameraStateToProps,
    stateSliceAccessor
  );
  const mapDispatchToProps = createSlicedDispatchToPropsMapper(
    mapCameraDispatchToProps,
    stateSliceAccessor
  );
  return Component => {
    const fn = (props: PassThroughProps) => <Component {...props} />;
    return connect(mapStateToProps, mapDispatchToProps)(fn);
  };
}
