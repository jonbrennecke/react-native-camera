// @flow
import React from 'react';
import { View, StyleSheet } from 'react-native';

import { Camera } from '../Camera';
import { CaptureButton } from '../CaptureButton';
import { CameraFocusArea } from '../CameraFocusArea';
import { RangeInputDial } from '../RangeInputDial';
import { Units } from '../../constants';

import type { SFC, Style, ReturnType } from '../../types';
import type { CameraISORange } from '../../state';

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
    flexDirection: 'column',
  },
  cameraWrap: {
    flex: 1,
    borderRadius: Units.small,
    overflow: 'hidden',
  },
  cameraControlsRow: {
    paddingVertical: Units.small,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
  },
  isoText: {
    color: '#fff',
  },
};

export type CameraCaptureProps = {
  style?: ?Style,
  cameraRef: ((?Camera) => void) | ReturnType<typeof React.createRef>,
  supportedISORange: CameraISORange,
  onRequestFocus: ({ x: number, y: number }) => void,
  onRequestBeginCapture: () => void,
  onRequestEndCapture: () => void,
};

export const CameraCapture: SFC<CameraCaptureProps> = ({
  style,
  cameraRef,
  supportedISORange,
  onRequestFocus,
  onRequestBeginCapture,
  onRequestEndCapture,
}: CameraCaptureProps) => (
  <View style={[styles.container, style]}>
    <View style={styles.cameraWrap}>
      <Camera ref={cameraRef} style={styles.flex} />
      <CameraFocusArea
        style={styles.absoluteFill}
        onRequestFocus={onRequestFocus}
      />
    </View>
    <View style={styles.bottomControls}>
      <View style={styles.cameraControlsRow}>
        <RangeInputDial supportedISORange={supportedISORange} />
      </View>
      <View style={styles.cameraControlsRow}>
        <CaptureButton
          onRequestBeginCapture={onRequestBeginCapture}
          onRequestEndCapture={onRequestEndCapture}
        />
      </View>
    </View>
  </View>
);
