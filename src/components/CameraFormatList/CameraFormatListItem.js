// @flow
import React from 'react';
import { View, Text } from 'react-native';

import type { SFC, Style } from '../../types';
import type { CameraFormat } from '../../state';

export type CameraFormatListItemProps = {
  style?: ?Style,
  format: CameraFormat,
  depthFormat: CameraFormat,
};

const styles = {
  container: {},
};

export const CameraFormatListItem: SFC<CameraFormatListItemProps> = ({
  style,
  format,
  depthFormat,
}: CameraFormatListItemProps) => (
  <View style={[styles.container, style]}>
    <Text>
      {`${format.dimensions.width}x${format.dimensions.height} - ${
        depthFormat.dimensions.width
      }x${depthFormat.dimensions.height}`}
    </Text>
  </View>
);
