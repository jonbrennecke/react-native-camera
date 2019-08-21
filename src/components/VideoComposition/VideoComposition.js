// @flow
import React, { Component } from 'react';
import {
  requireNativeComponent,
  findNodeHandle,
  NativeModules,
} from 'react-native';

import type { Style } from '../../types';

import type { CameraPreviewMode, CameraResizeMode } from '../Camera';

const NativeVideoCompositionView = requireNativeComponent(
  'HSVideoCompositionView'
);

const { HSVideoCompositionViewManager } = NativeModules;

export type VideoCompositionProps = {
  style?: ?Style,
  assetID: ?string,
  previewMode?: CameraPreviewMode,
  resizeMode?: CameraResizeMode,
  blurAperture?: number,
  isReadyToLoad?: boolean,
  onPlaybackProgress?: (progress: number) => void,
};

export class VideoComposition extends Component<VideoCompositionProps> {
  nativeComponentRef = React.createRef();

  play() {
    if (!this.nativeComponentRef) {
      return;
    }
    HSVideoCompositionViewManager.play(
      findNodeHandle(this.nativeComponentRef.current)
    );
  }

  pause() {
    if (!this.nativeComponentRef) {
      return;
    }
    HSVideoCompositionViewManager.pause(
      findNodeHandle(this.nativeComponentRef.current)
    );
  }

  seekToTime(seconds: number) {
    if (!this.nativeComponentRef) {
      return;
    }
    HSVideoCompositionViewManager.seekToTime(
      findNodeHandle(this.nativeComponentRef.current),
      seconds
    );
  }

  seekToProgress(progress: number) {
    if (!this.nativeComponentRef) {
      return;
    }
    HSVideoCompositionViewManager.seekToProgress(
      findNodeHandle(this.nativeComponentRef.current),
      progress
    );
  }

  render() {
    return (
      <NativeVideoCompositionView
        ref={this.nativeComponentRef}
        style={this.props.style}
        assetID={this.props.assetID}
        previewMode={this.props.previewMode}
        resizeMode={this.props.resizeMode}
        blurAperture={this.props.blurAperture}
        isReadyToLoad={this.props.isReadyToLoad}
        onPlaybackProgress={({ nativeEvent }) => {
          if (!nativeEvent) {
            return;
          }
          this.props.onPlaybackProgress(nativeEvent.progress);
        }}
      />
    );
  }
}
