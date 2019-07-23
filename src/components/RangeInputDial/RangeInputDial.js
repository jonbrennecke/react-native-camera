// @flow
import React from 'react';
import { ScrollView, View, Text, Dimensions } from 'react-native';
import times from 'lodash/times';
import clamp from 'lodash/clamp';
import round from 'lodash/round';

import { Units } from '../../constants';

import type { SFC, Style } from '../../types';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

const styles = {
  scrollView: {
    flexDirection: 'row',
  },
  scrollViewContent: {
    alignItems: 'center',
    paddingBottom: 15,
  },
  isoText: {
    color: '#fff',
    textAlign: 'center',
    position: 'absolute',
    fontSize: 10,
    bottom: -15,
    left: -10,
    width: 30,
  },
  tick: (index: number) => ({
    width: 2,
    height: index % 5 === 0 ? 30 : 10,
    borderRadius: 2,
    backgroundColor: '#fff',
    marginHorizontal: Units.extraSmall,
  }),
  padding: (width: number) => ({
    width,
  }),
};

export type RangeInputDialProps = {
  style?: ?Style,
  min: number,
  max: number,
  numberOfTicks?: number,
  formatValue?: number => string,
  onSelectValue: number => void,
};

const shouldDisplayIntegerValues = (min: number, max: number, numberOfTicks: number) =>
  Math.abs(max - min) >= numberOfTicks;

const makeDefaultValueFormatter = (isIntegerValued: boolean) =>
  (iso: number) =>
    `${parseFloat(iso)
      .toFixed(isIntegerValued ? 0 : 1)
      .toLocaleUpperCase()}`;

export const RangeInputDial: SFC<RangeInputDialProps> = ({
  style,
  min,
  max,
  numberOfTicks = 101,
  formatValue = makeDefaultValueFormatter(shouldDisplayIntegerValues(min, max, numberOfTicks)),
  onSelectValue,
}: RangeInputDialProps) => {
  const onScroll = ({ nativeEvent }) => {
    if (!nativeEvent) {
      return;
    }
    const { contentOffset, contentSize, layoutMeasurement } = nativeEvent;
    const percent =
      contentOffset.x / (contentSize.width - layoutMeasurement.width);
    const value = clamp(round(percent * (max - min) + min), min, max);
    onSelectValue(value);
  };
  const tickWidth = 2 + Units.extraSmall * 2;
  const contentOffset = SCREEN_WIDTH / 2 - tickWidth * 0.5;
  return (
    <ScrollView
      style={[style, styles.scrollView]}
      contentContainerStyle={styles.scrollViewContent}
      horizontal
      showsHorizontalScrollIndicator={false}
      onScroll={onScroll}
      scrollEventThrottle={16}
    >
      <View style={{ width: contentOffset }} />
      {times(numberOfTicks).map((n, i) => {
        const value = n / numberOfTicks * (max - min) + min;
        return (
          <View key={`${n}`}>
            <View style={styles.tick(i)} />
            {i % 5 === 0 && (
              <Text style={styles.isoText}>{formatValue(value)}</Text>
            )}
          </View>
        );
      })}
      <View style={{ width: contentOffset }} />
    </ScrollView>
  );
};
