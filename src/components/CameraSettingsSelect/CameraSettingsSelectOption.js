// @flow
import React from 'react';
import { TouchableOpacity, Text, View } from 'react-native';

import { Units } from '../../constants';

import type { SFC, Style } from '../../types';

export type CameraSettingsSelectOptionProps = {
  style?: ?Style,
  text: string,
  isSelected?: boolean,
};

export const styles = {
  container: (isSelected: boolean) => ({
    backgroundColor: isSelected ? '#fff' : 'transparent',
    borderRadius: Units.extraSmall,
  }),
  text: (isSelected: boolean) => ({
    color: isSelected ? '#000' : '#fff',
    fontSize: 10,
    fontWeight: 'bold',
    textAlign: 'center',
  }),
};

// eslint-disable-next-line flowtype/generic-spacing
export const CameraSettingsSelectOption: SFC<
  CameraSettingsSelectOptionProps
> = ({ style, text, isSelected = false }: CameraSettingsSelectOptionProps) => (
  <TouchableOpacity>
    <View style={[styles.container(isSelected), style]}>
      <Text style={styles.text(isSelected)} numberOfLines={1}>
        {text.toLocaleUpperCase()}
      </Text>
    </View>
  </TouchableOpacity>
);
