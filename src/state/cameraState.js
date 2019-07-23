// @flow
import { Record } from 'immutable';

import type { RecordOf, RecordInstance } from 'immutable';

export type CameraCaptureStatus = 'started' | 'stopped';

export type Range = { min: number, max: number }

export type CameraISORange = Range;
export type CameraExposureRange = Range;

export type CameraStateObject = {
  captureStatus: CameraCaptureStatus,
  supportedISORange: CameraISORange,
  supportedExposureRange: CameraExposureRange,
};

export type CameraStateRecord = RecordOf<CameraStateObject>;

export interface ICameraState {
  getCaptureStatus(): CameraCaptureStatus;
  setCaptureStatus(status: CameraCaptureStatus): ICameraState;

  getSupportedISORange(): CameraISORange;
  setSupportedISORange(range: CameraISORange): ICameraState;

  getSupportedExposureRange(): CameraExposureRange;
  setSupportedExposureRange(range: CameraExposureRange): ICameraState;
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

    getSupportedExposureRange(): CameraExposureRange {
      return this.get('supportedExposureRange');
    }

    setSupportedExposureRange(range: CameraExposureRange): ICameraState {
      return this.set('supportedExposureRange', range);
    }
  };
