// @flow
import { createReducer } from './createReducer';
import { createCameraState } from './cameraState';

import type { Action, Dispatch } from '../types';
import type {
  ICameraState,
  CameraCaptureStatus,
} from './cameraState';

const CameraState = createCameraState({
  captureStatus: 'stopped'
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
  }
};

export const {
  reducer,
  actionCreators: identityActionCreators,
} = createReducer(initialState, reducers);

export const actionCreators = {
  ...identityActionCreators,

  startCapture: () => (dispatch: Dispatch<*>) => {
    dispatch(actionCreators.setCaptureStatus({ captureStatus: 'started' }));
  },

  stopCapture: () => (dispatch: Dispatch<*>) => {
    dispatch(actionCreators.setCaptureStatus({ captureStatus: 'stopped' }));
  },
};
