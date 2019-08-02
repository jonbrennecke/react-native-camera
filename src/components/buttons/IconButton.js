// @flow
import React from 'react';
import { TouchableOpacity, StyleSheet } from 'react-native';

import type { SFC, Style, Children } from '../../types';

export type IconButtonProps = {
  style?: ?Style,
  children?: ?Children,
  onPress: () => void,
};

const styles = {
  button: {},
};

export const IconButton: SFC<IconButtonProps> = ({
  style,
  children,
  onPress,
}: IconButtonProps) => (
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
