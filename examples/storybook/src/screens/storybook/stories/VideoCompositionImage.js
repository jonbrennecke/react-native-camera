// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { withKnobs, number, select } from '@storybook/addon-knobs';
import { SafeAreaView } from 'react-native';
import { VideoCompositionImage } from '@jonbrennecke/react-native-camera';

const styles = {
  flex: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
    backgroundColor: '#000',
  },
};

const stories = storiesOf('Media Effects', module);
stories.addDecorator(withKnobs);
stories.add('Video Composition Image', () => (
  <SafeAreaView style={styles.safeArea}>
    <VideoCompositionImage
      style={styles.flex}
      resourceNameWithExt="onboarding.mov"
      previewMode={select(
        'Preview mode',
        {
          Normal: 'normal',
          Depth: 'depth',
          'Portrait mode': 'portraitMode',
        },
        'portraitMode'
      )}
      resizeMode={select(
        'Resize mode',
        {
          'Scale to fit width': 'scaleAspectWidth',
          'Scale to fit height': 'scaleAspectHeight',
          'Scale to fill': 'scaleAspectFill',
        },
        'scaleAspectWidth'
      )}
      blurAperture={number('Blur aperture', 1.4, {
        range: true,
        min: 1.4,
        max: 20,
        step: 0.1,
      })}
      progress={number('Progress', 0, {
        range: true,
        min: 0,
        max: 1,
        step: 0.01,
      })}
    />
  </SafeAreaView>
));
