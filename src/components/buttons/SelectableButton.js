// @flow
import React from 'react';
import { TouchableOpacity, Text, StyleSheet } from 'react-native';

import { Units } from '../../constants';

import type { SFC, Style } from '../../types';

export type SelectableButtonProps = {
  style?: ?Style,
  text: string,
  isSelected?: boolean,
  onPress: () => void,
};

const styles = {
  selectableButton: (isSelected: boolean) => ({
    backgroundColor: isSelected ? '#fff' : 'transparent',
    borderRadius: Units.extraSmall,
    paddingVertical: Units.small,
    paddingHorizontal: Units.large,
  }),
  selectableButtonText: (isSelected: boolean) => ({
    color: isSelected ? '#000' : '#fff',
    fontSize: 10,
    fontWeight: 'bold',
    textAlign: 'center',
  }),
};

export const SelectableButton: SFC<SelectableButtonProps> = ({
  style,
  text,
  isSelected = false,
  onPress,
}: SelectableButtonProps) => (
  <TouchableOpacity
    style={
      // $FlowFixMe
      StyleSheet.compose(styles.selectableButton(isSelected), style)
    }
    onPress={onPress}
  >
    <Text style={styles.selectableButtonText(isSelected)}>
      {text.toLocaleUpperCase()}
    </Text>
  </TouchableOpacity>
);
