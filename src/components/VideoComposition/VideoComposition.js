// @flow
import React, { PureComponent } from 'react';
import {
  requireNativeComponent,
  findNodeHandle,
  NativeModules,
} from 'react-native';

import type { Style } from '../../types';

import type { CameraPreviewMode, CameraResizeMode } from '../Camera';
import type { PlaybackState } from '../../state';

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
  onPlaybackStateChange?: (playbackState: PlaybackState) => void,
  onMetadataLoaded?: (metadata: { [key: string]: string }) => void,
};

export class VideoComposition extends PureComponent<VideoCompositionProps> {
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
          if (!nativeEvent || !this.props.onPlaybackProgress) {
            return;
          }
          this.props.onPlaybackProgress(nativeEvent.progress);
        }}
        onPlaybackStateChange={({ nativeEvent }) => {
          if (!nativeEvent || !this.props.onPlaybackStateChange) {
            return;
          }
          this.props.onPlaybackStateChange(nativeEvent.playbackState);
        }}
        onMetadataLoaded={({ nativeEvent }) => {
          if (!nativeEvent || !this.props.onMetadataLoaded) {
            return;
          }
          this.props.onMetadataLoaded(nativeEvent.metadata);
        }}
      />
    );
  }
}
