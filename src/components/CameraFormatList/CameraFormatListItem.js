// @flow
import React from 'react';
import { TouchableOpacity, Text } from 'react-native';

import { Units } from '../../constants';

import type { SFC, Style } from '../../types';
import type { CameraFormat } from '../../state';

export type CameraFormatListItemProps = {
  style?: ?Style,
  format: CameraFormat,
  depthFormat: CameraFormat,
  onPress: () => void,
};

const styles = {
  container: {
    paddingVertical: Units.small,
  },
  formatText: {
    color: '#fff',
    fontSize: 17,
    fontWeight: 'bold',
    textAlign: 'left',
  },
};

export const CameraFormatListItem: SFC<CameraFormatListItemProps> = ({
  style,
  format,
  depthFormat,
  onPress,
}: CameraFormatListItemProps) => (
  <TouchableOpacity style={[styles.container, style]} onPress={onPress}>
    <Text style={styles.formatText}>
      {`Video: ${formatDimensions(
        format.dimensions
      )} - Depth: ${formatDimensions(depthFormat.dimensions)}`}
    </Text>
  </TouchableOpacity>
);

const formatDimensions = (dimensions: {
  height: number,
  width: number,
}): string => `${dimensions.width}x${dimensions.height}`;
