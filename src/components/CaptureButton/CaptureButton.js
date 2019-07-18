// @flow
import React, { Component } from 'react';
import {
  View,
  Animated,
  TouchableWithoutFeedback,
  MaskedViewIOS,
  Easing,
} from 'react-native';
import { autobind } from 'core-decorators';
import { BlurView } from '@react-native-community/blur';

import type { Style } from '../../types';

type Props = {
  style?: ?Style,
  onRequestBeginCapture: () => void,
  onRequestEndCapture: () => void,
};

const AnimatedBlurView = Animated.createAnimatedComponent(BlurView);

const styles = {
  blurView: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
  outerViewAnim: (anim: Animated.Value) => ({
    height: 75,
    width: 75,
    borderRadius: 37.5,
    transform: [{ scale: anim }],
    shadowColor: '#000',
    shadowOpacity: 0.25,
    shadowOffset: {
      width: 1,
      height: 4,
    },
    shadowRadius: 5,
    alignItems: 'center',
    justifyContent: 'center',
  }),
  blurViewContainer: {
    height: 75,
    width: 75,
    borderRadius: 37.5,
    overflow: 'hidden',
  },
  border: {
    height: 75,
    width: 75,
    borderRadius: 37.5,
    borderWidth: 4,
    borderColor: 'red',
    position: 'absolute',
  },
  borderMask: {
    height: 75,
    width: 75,
    borderRadius: 37.5,
    position: 'absolute',
  },
  inner: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: '#fff',
  },
  progress: {
    height: 75,
    width: 75,
    borderRadius: 37.5,
    position: 'absolute',
  },
};

// $FlowFixMe
@autobind
export class CaptureButton extends Component<Props> {
  outerViewAnim: Animated.Value = new Animated.Value(1);

  touchableOnPressIn() {
    Animated.spring(this.outerViewAnim, {
      toValue: 1.35,
      duration: 350,
      useNativeDriver: true,
      easing: Easing.out(Easing.quad),
    }).start();
    this.props.onRequestBeginCapture();
  }

  touchableOnPressOut() {
    Animated.spring(this.outerViewAnim, {
      toValue: 1.0,
      duration: 350,
      useNativeDriver: true,
      easing: Easing.out(Easing.quad),
    }).start();
    this.props.onRequestEndCapture();
  }

  render() {
    return (
      <TouchableWithoutFeedback
        onPressIn={this.touchableOnPressIn}
        onPressOut={this.touchableOnPressOut}
      >
        <Animated.View style={styles.outerViewAnim(this.outerViewAnim)}>
          <View style={styles.blurViewContainer}>
            <AnimatedBlurView
              style={[styles.blurView, this.props.style]}
              blurType="light"
            />
          </View>
          <MaskedViewIOS
            style={styles.borderMask}
            maskElement={<View style={styles.border} />}
          >
            <View style={styles.inner} />
          </MaskedViewIOS>
        </Animated.View>
      </TouchableWithoutFeedback>
    );
  }
}