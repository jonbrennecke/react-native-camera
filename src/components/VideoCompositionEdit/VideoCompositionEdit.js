// @flow
import React from 'react';
import { View, TouchableOpacity, Text } from 'react-native';

import { VideoComposition } from '../VideoComposition';

import type { SFC, Style } from '../../types';

export type VideoCompositionEditProps = {
  style?: ?Style,
  assetID: ?string,
  enableDepthPreview?: boolean,
};

const styles = {
  flex: {
    flex: 1,
  },
  container: {
    backgroundColor: '#000',
  },
  toolbar: {},
  buttonText: {
    color: '#fff',
  },
};

export const VideoCompositionEdit: SFC<VideoCompositionEditProps> = ({
  style,
  assetID,
  enableDepthPreview = true,
}: VideoCompositionEditProps) => (
  <View style={[styles.container, style]}>
    <VideoComposition
      style={styles.flex}
      assetID={assetID}
      enableDepthPreview={enableDepthPreview}
      shouldLoopVideo
    />
    <View style={styles.toolbar}>
      <TouchableOpacity>
        <Text style={styles.buttonText}>Portrait</Text>
      </TouchableOpacity>
    </View>
  </View>
);
