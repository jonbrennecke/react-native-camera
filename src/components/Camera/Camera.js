// @flow
import React, { PureComponent } from 'react';
import {
  requireNativeComponent,
  findNodeHandle,
  NativeModules,
} from 'react-native';

import type { Style } from '../../types';

const NativeCameraView = requireNativeComponent('HSCameraView');

const { HSCameraViewManager } = NativeModules;

export type CameraPosition = 'front' | 'back';

export type CameraPreviewMode = 'normal' | 'depth' | 'portraitMode';

export type CameraResizeMode =
  | 'scaleAspectWidth'
  | 'scaleAspectHeight'
  | 'scaleAspectFill';

export const CameraResolutionPresets = {
  hd720p: 'hd720p',
  hd1080p: 'hd1080p',
  hd4K: 'hd4K',
  vga: 'vga',
};

export type CameraProps = {
  style?: ?Style,
  resolutionPreset?: $Keys<typeof CameraResolutionPresets>,
  cameraPosition?: CameraPosition,
  previewMode?: CameraPreviewMode,
  resizeMode?: CameraResizeMode,
  blurAperture?: number,
  isPaused?: boolean,
  watermarkImageNameWithExtension?: ?string,
};

export class Camera extends PureComponent<CameraProps> {
  nativeComponentRef = React.createRef();

  focusOnPoint(point: { x: number, y: number }) {
    if (!this.nativeComponentRef) {
      return;
    }
    HSCameraViewManager.focusOnPoint(
      findNodeHandle(this.nativeComponentRef.current),
      point
    );
  }

  render() {
    return (
      <NativeCameraView
        ref={this.nativeComponentRef}
        style={this.props.style}
        cameraPosition={this.props.cameraPosition}
        previewMode={this.props.previewMode}
        resizeMode={this.props.resizeMode}
        blurAperture={this.props.blurAperture}
        isPaused={this.props.isPaused}
        watermarkImageNameWithExtension={
          this.props.watermarkImageNameWithExtension
        }
        resolutionPreset={this.props.resolutionPreset}
        pointerEvents="none"
      />
    );
  }
}
