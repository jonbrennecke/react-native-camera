// @flow
import React from 'react';
import { requireNativeComponent } from 'react-native';

import type { Style, SFC } from '../../types';

import type { CameraPreviewMode, CameraResizeMode } from '../Camera';

const NativeVideoCompositionImageView = requireNativeComponent(
  'HSVideoCompositionImageView'
);

export type VideoCompositionImageProps = {
  style?: ?Style,
  resourceNameWithExt: string,
  previewMode?: CameraPreviewMode,
  resizeMode?: CameraResizeMode,
  blurAperture?: number,
  progress?: number,
};

export const VideoCompositionImage: SFC<VideoCompositionImageProps> = ({
  style,
  resourceNameWithExt,
  previewMode,
  resizeMode,
  blurAperture,
  progress
}: VideoCompositionImageProps) => (
  <NativeVideoCompositionImageView
    style={style}
    resourceNameWithExt={resourceNameWithExt}
    previewMode={previewMode}
    resizeMode={resizeMode}
    blurAperture={blurAperture}
    progress={progress}
  />
);
