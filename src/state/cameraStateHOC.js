// @flow
import React from 'react';
import { connect } from 'react-redux';
import identity from 'lodash/identity';

import {
  actionCreators,
  selectCaptureStatus,
  selectSupportedISORange,
  selectSupportedExposureRange,
  selectISO,
  selectExposure,
} from './';

import type { ComponentType } from 'react';

import type { Dispatch } from '../types';
import type {
  ICameraState,
  CameraCaptureStatus,
  CameraISORange,
  CameraExposureRange,
} from './';

type OwnProps = {};

type StateProps = {
  captureStatus: CameraCaptureStatus,
  supportedISORange: CameraISORange,
  supportedExposureRange: CameraExposureRange,
  iso: number,
};

type DispatchProps = {
  startCapture: () => any,
  stopCapture: ({ saveToCameraRoll: boolean }) => any,
  loadSupportedISORange: () => any,
  loadSupportedExposureRange: () => any,
  loadSupportedFeatures: () => any,
  updateISO: (iso: number) => any,
};

export type CameraStateHOCProps = OwnProps & StateProps & DispatchProps;

function mapCameraStateToProps(state: ICameraState): StateProps {
  return {
    captureStatus: selectCaptureStatus(state),
    supportedISORange: selectSupportedISORange(state),
    supportedExposureRange: selectSupportedExposureRange(state),
    iso: selectISO(state),
    exposure: selectExposure(state),
  };
}

function mapCameraDispatchToProps(dispatch: Dispatch<any>): DispatchProps {
  return {
    startCapture: () => dispatch(actionCreators.startCapture()),
    stopCapture: (args: { saveToCameraRoll: boolean }) =>
      dispatch(actionCreators.stopCapture(args)),
    loadSupportedISORange: () =>
      dispatch(actionCreators.loadSupportedISORange()),
    loadSupportedExposureRange: () =>
      dispatch(actionCreators.loadSupportedExposureRange()),
    loadSupportedFeatures: () =>
      dispatch(actionCreators.loadSupportedFeatures()),
    updateISO: (iso: number) => dispatch(actionCreators.updateISO(iso)),
    updateExposure: (exposure: number) =>
      dispatch(actionCreators.updateExposure(exposure)),
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
