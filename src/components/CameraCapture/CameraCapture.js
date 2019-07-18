// @flow
import React from 'react';
import { View } from 'react-native';

import { Camera } from '../Camera';
import { CaptureButton } from '../CaptureButton';

import type { SFC, Style } from '../../types';

const styles = {
  flex: {
    flex: 1,
  },
  bottomControls: {
    position: 'absolute',
    bottom: 10,
    left: 0,
    right: 0,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  }
};

export type CameraCaptureProps = {
  style?: ?Style,
  onRequestBeginCapture: () => void,
  onRequestEndCapture: () => void,
};

export const CameraCapture: SFC<CameraCaptureProps> = ({
  style,
  onRequestBeginCapture,
  onRequestEndCapture
}: CameraCaptureProps) => (
  <View style={style}>
    <Camera style={styles.flex} />
    <View style={styles.bottomControls}>
      <CaptureButton
        onRequestBeginCapture={onRequestBeginCapture}
        onRequestEndCapture={onRequestEndCapture}
      />
    </View>
  </View>
);
