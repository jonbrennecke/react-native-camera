// @flow
import React from 'react';
import { ScrollView, View, Text } from 'react-native';
import times from 'lodash/times';

import { Units } from '../../constants';

import type { SFC, Style } from '../../types';
import type { CameraISORange } from '../../state';

const styles = {
  scrollView: {
    flexDirection: 'row',
  },
  scrollViewContent: {
    alignItems: 'center',
    paddingBottom: 15,
    paddingHorizontal: Units.small,
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
  verticalBar: (index: number) => ({
    width: 2,
    height: index % 5 === 0 ? 30 : 10,
    borderRadius: 2,
    backgroundColor: '#fff',
    marginHorizontal: Units.extraSmall,
  }),
};

export type RangeInputDialProps = {
  style?: ?Style,
  supportedISORange: CameraISORange,
};

export const RangeInputDial: SFC<RangeInputDialProps> = ({
  style,
  supportedISORange,
}: RangeInputDialProps) => (
  <ScrollView
    style={[style, styles.scrollView]}
    contentContainerStyle={styles.scrollViewContent}
    horizontal
  >
    {times(101).map((n, i) => {
      const iso = n / 101 * supportedISORange.max + supportedISORange.min;
      return (
        <View key={`${n}`}>
          <View style={styles.verticalBar(i)} />
          {i % 5 === 0 && <Text style={styles.isoText}>{formatISO(iso)}</Text>}
        </View>
      );
    })}
  </ScrollView>
);

const formatISO = (iso: number) => `${parseInt(iso).toString().toLocaleUpperCase()}`;
