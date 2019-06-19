// @flow
import React from 'react';
import { requireNativeComponent } from 'react-native';

import type { SFC, Style } from '../../types';

const NativeCameraView = requireNativeComponent('HSCameraView');

export type CameraProps = {
  style?: ?Style,
};

export const Camera: SFC<CameraProps> = ({ style }: CameraProps) => (
  <NativeCameraView style={style} />
);
