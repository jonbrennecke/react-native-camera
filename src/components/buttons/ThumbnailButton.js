// @flow
import React from 'react';
import { TouchableOpacity, StyleSheet } from 'react-native';

import { Units } from '../../constants';

import type { SFC, Style, Children } from '../../types';

export type ThumbnailButtonProps = {
  style?: ?Style,
  children?: ?Children,
  onPress: () => void,
};

const styles = {
  button: {
    height: 75 - Units.small,
    width: 75 - Units.small,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#ccc',
    borderRadius: Units.extraSmall,
    padding: Units.extraSmall,
  },
};

export const ThumbnailButton: SFC<ThumbnailButtonProps> = ({
  style,
  children,
  onPress,
}: ThumbnailButtonProps) => (
  <TouchableOpacity
    style={
      // $FlowFixMe
      StyleSheet.compose(styles.button, style)
    }
    onPress={onPress}
  >
    {children}
  </TouchableOpacity>
);
