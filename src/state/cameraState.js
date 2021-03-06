// @flow
import { Record } from 'immutable';

import type { RecordOf, RecordInstance, Map } from 'immutable';

export type CameraCaptureStatus = 'started' | 'stopped';

export type PlaybackState = 'playing' | 'paused' | 'waiting' | 'readyToPlay';

export type Range = { min: number, max: number };

export type CameraISORange = Range;
export type CameraExposureRange = Range;
export type CameraFrameRateRange = Range;
export type CameraDeviceSupportObject = {
  hasSupportedFrontCamera: boolean,
  hasSupportedBackCamera: boolean,
};

export type CameraFormat = {
  dimensions: { width: number, height: number },
  mediaType: string,
  mediaSubType: string,
  supportedFrameRates: CameraFrameRateRange,
  supportedDepthFormats: CameraFormat[],
};

export type CameraStateObject = {
  captureStatus: CameraCaptureStatus,
  lastCapturedVideoURL: ?string,
  supportedISORange: CameraISORange,
  supportedExposureRange: CameraExposureRange,
  supportedFormats: CameraFormat[],
  blurAperture: number,
  iso: number,
  exposure: number,
  format: ?CameraFormat,
  depthFormat: ?CameraFormat,
  hasCameraPermissions: boolean,
  playbackStateMap: Map<string, PlaybackState>,
  playbackProgress: number,
  cameraDeviceSupport: ?CameraDeviceSupportObject,
};

export type CameraStateRecord = RecordOf<CameraStateObject>;

export interface ICameraState {
  getCaptureStatus(): CameraCaptureStatus;
  setCaptureStatus(status: CameraCaptureStatus): ICameraState;

  getSupportedISORange(): CameraISORange;
  setSupportedISORange(range: CameraISORange): ICameraState;

  getSupportedExposureRange(): CameraExposureRange;
  setSupportedExposureRange(range: CameraExposureRange): ICameraState;

  getSupportedFormats(): CameraFormat[];
  setSupportedFormats(formats: CameraFormat[]): ICameraState;

  getISO(): number;
  setISO(iso: number): ICameraState;

  getExposure(): number;
  setExposure(exposure: number): ICameraState;

  hasCameraPermissions(): boolean;
  setHasCameraPermissions(hasCameraPermissions: boolean): ICameraState;

  getFormat(): ?CameraFormat;
  setFormat(format: CameraFormat): ICameraState;

  getDepthFormat(): ?CameraFormat;
  setDepthFormat(depthFormat: CameraFormat): ICameraState;

  getBlurAperture(): number;
  setBlurAperture(blurAperture: number): ICameraState;

  getPlaybackStateMap(): Map<string, PlaybackState>;
  setPlaybackStateMap(
    playbackStateMap: Map<string, PlaybackState>
  ): ICameraState;

  getPlaybackState(assetID: string): ?PlaybackState;
  setPlaybackState(assetID: string, playbackState: PlaybackState): ICameraState;

  getPlaybackProgress(): number;
  setPlaybackProgress(progress: number): ICameraState;

  getLastCapturedVideoURL(): ?string;
  setLastCapturedVideoURL(url: ?string): ICameraState;

  getCameraDeviceSupport(): ?CameraDeviceSupportObject;
  setCameraDeviceSupport(
    deviceSupport: CameraDeviceSupportObject
  ): ICameraState;
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

    getSupportedFormats(): CameraFormat[] {
      return this.get('supportedFormats');
    }

    setSupportedFormats(formats: CameraFormat[]) {
      return this.set('supportedFormats', formats);
    }

    getISO(): number {
      return this.get('iso');
    }

    setISO(iso: number): ICameraState {
      return this.set('iso', iso);
    }

    getExposure(): number {
      return this.get('exposure');
    }

    setExposure(exposure: number): ICameraState {
      return this.set('exposure', exposure);
    }

    hasCameraPermissions(): boolean {
      return !!this.get('hasCameraPermissions');
    }

    setHasCameraPermissions(hasCameraPermissions: boolean): ICameraState {
      return this.set('hasCameraPermissions', hasCameraPermissions);
    }

    getFormat(): ?CameraFormat {
      return this.get('format');
    }

    setFormat(format: CameraFormat): ICameraState {
      return this.set('format', format);
    }

    getDepthFormat(): ?CameraFormat {
      return this.get('depthFormat');
    }

    setDepthFormat(depthFormat: CameraFormat): ICameraState {
      return this.set('depthFormat', depthFormat);
    }

    getBlurAperture(): number {
      return this.get('blurAperture') || 0;
    }

    setBlurAperture(blurAperture: number): ICameraState {
      return this.set('blurAperture', blurAperture);
    }

    getPlaybackStateMap(): Map<string, PlaybackState> {
      return this.get('playbackStateMap');
    }

    setPlaybackStateMap(
      playbackStateMap: Map<string, PlaybackState>
    ): ICameraState {
      return this.set('playbackStateMap', playbackStateMap);
    }

    getPlaybackState(assetID: string): ?PlaybackState {
      return this.getPlaybackStateMap().get(assetID);
    }

    setPlaybackState(
      assetID: string,
      playbackState: PlaybackState
    ): ICameraState {
      const playbackStateMap = this.getPlaybackStateMap();
      const updatedPlaybackStateMap = playbackStateMap.set(
        assetID,
        playbackState
      );
      return this.setPlaybackStateMap(updatedPlaybackStateMap);
    }

    getPlaybackProgress(): number {
      return this.get('playbackProgress');
    }

    setPlaybackProgress(progress: number): ICameraState {
      return this.set('playbackProgress', progress);
    }

    getLastCapturedVideoURL(): ?string {
      return this.get('lastCapturedVideoURL');
    }

    setLastCapturedVideoURL(url: ?string): ICameraState {
      return this.set('lastCapturedVideoURL', url);
    }

    getCameraDeviceSupport(): ?CameraDeviceSupportObject {
      return this.get('cameraDeviceSupport');
    }

    setCameraDeviceSupport(
      deviceSupport: CameraDeviceSupportObject
    ): ICameraState {
      return this.set('cameraDeviceSupport', deviceSupport);
    }
  };
