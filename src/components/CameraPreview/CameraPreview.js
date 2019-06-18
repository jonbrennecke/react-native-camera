// @flow
import React from 'react';
import { requireNativeComponent } from 'react-native';

import type { SFC, Style } from '../../types';

const NativeCameraPreviewView = requireNativeComponent('HSCameraPreviewView');

export type CameraPreviewProps = {
  style?: ?Style,
};

export const CameraPreview: SFC<CameraPreviewProps> = ({
  style,
}: CameraPreviewProps) => <NativeCameraPreviewView style={style} />;
