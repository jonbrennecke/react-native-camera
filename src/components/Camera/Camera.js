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

export type CameraProps = {
  style?: ?Style,
  cameraPosition?: CameraPosition,
  previewMode?: CameraPreviewMode,
  resizeMode?: CameraResizeMode,
  blurAperture?: number,
  isPaused?: boolean,
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
        pointerEvents="none"
      />
    );
  }
}
