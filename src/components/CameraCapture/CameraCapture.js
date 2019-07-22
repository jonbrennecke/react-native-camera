// @flow
import React from 'react';
import { View, StyleSheet } from 'react-native';

import { Camera } from '../Camera';
import { CaptureButton } from '../CaptureButton';
import { CameraFocusArea } from '../CameraFocusArea';
import { Units } from '../../constants';

import type { SFC, Style } from '../../types';

const styles = {
  flex: {
    flex: 1,
  },
  absoluteFill: {
    ...StyleSheet.absoluteFillObject,
  },
  container: {
    backgroundColor: '#000',
  },
  bottomControls: {
    paddingVertical: Units.small,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  cameraWrap: {
    flex: 1,
    borderRadius: Units.small,
    overflow: 'hidden',
  },
};

export type CameraCaptureProps = {
  style?: ?Style,
  onRequestBeginCapture: () => void,
  onRequestEndCapture: () => void,
};

export const CameraCapture: SFC<CameraCaptureProps> = ({
  style,
  onRequestBeginCapture,
  onRequestEndCapture,
}: CameraCaptureProps) => (
  <View style={[styles.container, style]}>
    <View style={styles.cameraWrap}>
      <Camera style={styles.flex} />
      <CameraFocusArea
        style={styles.absoluteFill}
        onDidRequestFocusOnPoint={() => {}}
      />
    </View>
    <View style={styles.bottomControls}>
      <CaptureButton
        onRequestBeginCapture={onRequestBeginCapture}
        onRequestEndCapture={onRequestEndCapture}
      />
    </View>
  </View>
);
