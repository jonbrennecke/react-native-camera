// @flow
import React from 'react';
import { View, ScrollView, Dimensions } from 'react-native';
import clamp from 'lodash/clamp';
import round from 'lodash/round';

import { CameraSettingsSelectOption } from './CameraSettingsSelectOption';
import { Units } from '../../constants';

import type { SFC, Style } from '../../types';

export type CameraSettingsSelectProps = {
  style?: ?Style,
  options: any[],
  isSelectedOption: any => boolean,
  keyForOption: any => string,  
  labelTextForOption: any => string,
  onRequestSelectOption: any => void,
};

const { width: SCREEN_WIDTH } = Dimensions.get('window');
const OPTION_WIDTH = 75;

export const styles = {
  scrollView: {
    flexDirection: 'row',
  },
  scrollViewContent: {
    alignItems: 'center',
  },
  option: {
    width: OPTION_WIDTH,
    marginHorizontal: Units.small,
    paddingVertical: Units.small,
  },
};

export const CameraSettingsSelect: SFC<CameraSettingsSelectProps> = ({
  style,
  options,
  isSelectedOption,
  keyForOption,
  labelTextForOption,
  onRequestSelectOption,
}: CameraSettingsSelectProps) => {
  const onScroll = ({ nativeEvent }) => {
    if (!nativeEvent) {
      return;
    }
    const { contentOffset, contentSize, layoutMeasurement } = nativeEvent;
    const percent =
      contentOffset.x / (contentSize.width - layoutMeasurement.width);
    const index = Math.abs(
      clamp(round(percent * (options.length - 1)), 0, options.length - 1)
    );
    onRequestSelectOption(options[index]);
  };
  const optionWidth = OPTION_WIDTH + Units.small * 2;
  const contentOffset = (SCREEN_WIDTH - optionWidth) * 0.5;
  return (
    <ScrollView
      style={[style, styles.scrollView]}
      contentContainerStyle={styles.scrollViewContent}
      horizontal
      snapToInterval={optionWidth}
      showsHorizontalScrollIndicator={false}
      onScroll={onScroll}
      scrollEventThrottle={16}
      decelerationRate="fast"
    >
      <View style={{ width: contentOffset }} />
      {options.map(option => (
        <CameraSettingsSelectOption
          key={keyForOption(option)}
          style={styles.option}
          text={labelTextForOption(option)}
          isSelected={isSelectedOption(option)}
        />
      ))}
      <View style={{ width: contentOffset }} />
    </ScrollView>
  );
};
