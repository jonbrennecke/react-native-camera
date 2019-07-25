// @flow
import React from 'react';
import { View, TouchableOpacity, Text } from 'react-native';
import noop from 'lodash/noop';

import { Seekbar } from '@jonbrennecke/react-native-media';

import { SelectableButton } from '../buttons';
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
  onRequestToggleDepthPreview: () => void,
  onRequestExport: () => void,
};

const styles = {
  flex: {
    flex: 1,
  },
  container: {
    backgroundColor: '#000',
  },
  toolbar: ({ align = 'center' }: { align?: 'left' | 'right' | 'center' }) => ({
    paddingVertical: Units.small,
    paddingHorizontal: align !== 'center' ? Units.small : 0,
    alignItems: 'center',
    justifyContent: {
      'left': 'flex-start',
      'right': 'flex-end',
      'center': 'center'
    }[align],
    flexDirection: 'row',
  }),
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
  button: {
    backgroundColor: '#fff',
    borderRadius: Units.extraSmall,
    paddingVertical: Units.small,
    paddingHorizontal: Units.large,
  },
  buttonText: {
    color: '#000',
    fontSize: 10,
    fontWeight: 'bold',
    textAlign: 'center',
  },
  buttonSeparator: {
    width: Units.small,
  },
};

export const VideoCompositionEdit: SFC<VideoCompositionEditProps> = ({
  style,
  asset,
  playbackTime,
  enableDepthPreview = true,
  enablePortraitMode,
  onRequestTogglePortraitMode,
  onRequestToggleDepthPreview,
  onRequestExport,
}: VideoCompositionEditProps) => (
  <View style={[styles.container, style]}>
    <View style={styles.toolbar({ align: 'right' })}>
      <TouchableOpacity style={styles.button} onPress={onRequestExport}>
        <Text style={styles.buttonText}>{'Export'.toLocaleUpperCase()}</Text>
      </TouchableOpacity>
    </View>
    <VideoComposition
      style={styles.flex}
      assetID={asset?.assetID}
      enableDepthPreview={enableDepthPreview}
      enablePortraitMode={enablePortraitMode}
      shouldLoopVideo
    />
    <View style={styles.toolbar({})}>
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
    <View style={styles.toolbar({})}>
      <SelectableButton
        text="Portrait"
        isSelected={enablePortraitMode}
        onPress={onRequestTogglePortraitMode}
      />
      <View style={styles.buttonSeparator} />
      <SelectableButton
        text="Depth"
        isSelected={enableDepthPreview}
        onPress={onRequestToggleDepthPreview}
      />
    </View>
  </View>
);
