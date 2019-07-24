// @flow
import React from 'react';
import { requireNativeComponent } from 'react-native';

import type { SFC, Style } from '../../types';

const NativeVideoCompositionView = requireNativeComponent(
  'HSVideoCompositionView'
);

export type VideoCompositionProps = {
  style?: ?Style,
  assetID: ?string,
  enableDepthPreview?: boolean,
  enablePortraitMode?: boolean,
  shouldLoopVideo?: boolean,
};

export const VideoComposition: SFC<VideoCompositionProps> = ({
  style,
  assetID,
  enableDepthPreview = true,
  enablePortraitMode = true,
  shouldLoopVideo = true,
}: VideoCompositionProps) => (
  <NativeVideoCompositionView
    style={style}
    assetID={assetID}
    isDepthPreviewEnabled={enableDepthPreview}
    isPortraitModeEnabled={enablePortraitMode}
    shouldLoopVideo={shouldLoopVideo}
  />
);
