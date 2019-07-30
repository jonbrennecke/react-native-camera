// @flow
import React from 'react';
import { TouchableOpacity, Text, View } from 'react-native';

import { Units } from '../../constants';

import type { SFC, Style } from '../../types';
import type { CameraFormat } from '../../state';

export type CameraFormatListItemProps = {
  style?: ?Style,
  isActive?: boolean,
  format: CameraFormat,
  depthFormat: CameraFormat,
  onPress: () => void,
};

const styles = {
  container: {
    paddingVertical: Units.small,
  },
  formatText: (isActive: boolean) => ({
    color: isActive ? '#fff' : '#999',
    fontSize: 17,
    fontWeight: 'bold',
    textAlign: 'left',
  }),
};

export const CameraFormatListItem: SFC<CameraFormatListItemProps> = ({
  style,
  isActive = false,
  format,
  onPress,
}: CameraFormatListItemProps) => (
  <TouchableOpacity onPress={onPress}>
    <View style={[styles.container, style]}>
      <Text style={styles.formatText(isActive)}>
        {`Video: ${formatDimensions(format.dimensions)}`}
      </Text>
    </View>
  </TouchableOpacity>
);

const formatDimensions = (dimensions: {
  height: number,
  width: number,
}): string => `${dimensions.width}x${dimensions.height}`;
