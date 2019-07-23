// @flow
import { Record } from 'immutable';

import type { RecordOf, RecordInstance } from 'immutable';

export type CameraCaptureStatus = 'started' | 'stopped';

export type CameraISORange = { min: number, max: number };

export type CameraStateObject = {
  captureStatus: CameraCaptureStatus,
  supportedISORange: CameraISORange,
};

export type CameraStateRecord = RecordOf<CameraStateObject>;

export interface ICameraState {
  getCaptureStatus(): CameraCaptureStatus;
  setCaptureStatus(status: CameraCaptureStatus): ICameraState;

  getSupportedISORange(): CameraISORange;
  setSupportedISORange(range: CameraISORange): ICameraState;
}

// eslint-disable-next-line flowtype/generic-spacing
export const createCameraState: CameraStateObject => Class<
  RecordInstance<CameraStateRecord> & ICameraState
> = defaultState =>
  class CameraState extends Record(defaultState) implements ICameraState {
    getCaptureStatus(): CameraCaptureStatus {
      return this.get('captureStatus');
    }

    setCaptureStatus(status: CameraCaptureStatus): ICameraState {
      return this.set('captureStatus', status);
    }

    getSupportedISORange(): CameraISORange {
      return this.get('supportedISORange');
    }

    setSupportedISORange(range: CameraISORange): ICameraState {
      return this.set('supportedISORange', range);
    }
  };
