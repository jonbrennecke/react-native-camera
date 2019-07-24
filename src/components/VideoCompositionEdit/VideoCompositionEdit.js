// @flow
import React from 'react';
import { View, TouchableOpacity, Text } from 'react-native';
import noop from 'lodash/noop';

import { Seekbar } from '@jonbrennecke/react-native-media';

import { VideoComposition } from '../VideoComposition';
import { Units } from '../../constants';

import type { MediaObject } from '@jonbrennecke/react-native-media';

import type { SFC, Style } from '../../types';

export type VideoCompositionEditProps = {
  style?: ?Style,
  asset: ?MediaObject,
  playbackTime: ?number,
  enableDepthPreview?: boolean,
  enablePortraitMode: boolean,
  onRequestTogglePortraitMode: () => void,
};

const styles = {
  flex: {
    flex: 1,
  },
  container: {
    backgroundColor: '#000',
  },
  toolbar: {
    paddingVertical: Units.small,
    alignItems: 'center',
    justifyContent: 'center',
    flexDirection: 'row',
  },
  seekbar: {
    height: 50,
    width: '100%',
    borderRadius: 0,
  },
  seekbarHandle: {
    backgroundColor: '#fff',
  },
  seekbarBackground: {
    borderRadius: 0,
  },
  button: (isSelected: boolean) => ({
    backgroundColor: isSelected ? '#fff' : 'transparent',
    borderRadius: Units.extraSmall,
    paddingVertical: Units.small,
    paddingHorizontal: Units.large,
  }),
  buttonText: (isSelected: boolean) => ({
    color: isSelected ? '#000' : '#fff',
    fontSize: 10,
    fontWeight: 'bold',
    textAlign: 'center',
  }),
};

export const VideoCompositionEdit: SFC<VideoCompositionEditProps> = ({
  style,
  asset,
  playbackTime,
  enableDepthPreview = true,
  enablePortraitMode,
  onRequestTogglePortraitMode,
}: VideoCompositionEditProps) => (
  <View style={[styles.container, style]}>
    <VideoComposition
      style={styles.flex}
      assetID={asset?.assetID}
      enableDepthPreview={enableDepthPreview}
      enablePortraitMode={enablePortraitMode}
      shouldLoopVideo
    />
    <View style={styles.toolbar}>
      {asset && (
        <Seekbar
          style={styles.seekbar}
          handleStyle={styles.seekbarHandle}
          backgroundStyle={styles.seekbarBackground}
          assetID={asset.assetID}
          duration={asset.duration}
          playbackTime={playbackTime || 0}
          onDidBeginDrag={noop}
          onDidEndDrag={noop}
          onSeekToTime={noop}
        />
      )}
    </View>
    <View style={styles.toolbar}>
      <TouchableOpacity
        style={styles.button(enablePortraitMode)}
        onPress={onRequestTogglePortraitMode}
      >
        <Text style={styles.buttonText(enablePortraitMode)}>
          {'Portrait'.toLocaleUpperCase()}
        </Text>
      </TouchableOpacity>
    </View>
  </View>
);
