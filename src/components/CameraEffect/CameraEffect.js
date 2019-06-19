// @flow
import React from 'react';
import { requireNativeComponent } from 'react-native';

import type { SFC, Style } from '../../types';

const NativeCameraEffectView = requireNativeComponent('HSCameraEffectView');

export type CameraEffectProps = {
  style?: ?Style,
};

export const CameraEffect: SFC<CameraEffectProps> = ({
  style,
}: CameraEffectProps) => <NativeCameraEffectView style={style} />;
