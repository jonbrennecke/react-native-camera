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
};

export const VideoComposition: SFC<VideoCompositionProps> = ({
  style,
  assetID,
}: VideoCompositionProps) => (
  <NativeVideoCompositionView style={style} assetID={assetID} />
);
