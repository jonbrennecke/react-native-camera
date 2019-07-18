// @flow
import { createReducer } from './createReducer';
import { createCameraState } from './cameraState';
import { startCameraCapture, stopCameraCapture } from '../utils';

import type { Action, Dispatch } from '../types';
import type { ICameraState, CameraCaptureStatus } from './cameraState';

const CameraState = createCameraState({
  captureStatus: 'stopped',
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
};

export const {
  reducer,
  actionCreators: identityActionCreators,
} = createReducer(initialState, reducers);

export const actionCreators = {
  ...identityActionCreators,

  startCapture: () => async (dispatch: Dispatch<*>) => {
    await startCameraCapture();
    dispatch(actionCreators.setCaptureStatus({ captureStatus: 'started' }));
  },

  stopCapture: ({
    saveToCameraRoll = false,
  }: {
    saveToCameraRoll: boolean,
  }) => async (dispatch: Dispatch<*>) => {
    await stopCameraCapture({ saveToCameraRoll });
    dispatch(actionCreators.setCaptureStatus({ captureStatus: 'stopped' }));
  },
};
