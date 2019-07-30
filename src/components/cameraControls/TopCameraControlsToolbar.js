// @flow
import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';

import type { SFC, Style } from '../../types';

const styles = {
  container: {
    borderBottomColor: '#222',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomStyle: 'solid',
  },
  controlsRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'flex-end',
  },
  text: {
    color: '#fff',
    fontSize: 10,
    fontWeight: 'bold',
    textAlign: 'center',
  },
};

export type TopCameraControlsToolbarProps = {
  style?: ?Style,
  onRequestShowFormatDialog: () => void,
};

export const TopCameraControlsToolbar: SFC<TopCameraControlsToolbarProps> = ({
  style,
  onRequestShowFormatDialog,
}: TopCameraControlsToolbarProps) => {
  return (
    <View style={[styles.container, style]}>
      <View style={styles.controlsRow}>
        <TouchableOpacity onPress={onRequestShowFormatDialog}>
          <Text style={styles.text}>{'Resolution'.toLocaleUpperCase()}</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
};
