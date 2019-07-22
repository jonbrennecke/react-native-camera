// @flow
import React, { Component } from 'react';
import {
  View,
  TouchableWithoutFeedback,
  Animated,
  Easing,
  findNodeHandle,
} from 'react-native';
import { autobind } from 'core-decorators';

import { Units } from '../../constants';

import type { Style } from '../../types/react';

type FocusPoint = { x: number, y: number };

type Props = {
  style?: ?Style,
  onRequestFocus: FocusPoint => void,
};

type State = {
  focusPoint: FocusPoint,
};

const styles = {
  container: {},
  focusArea: ({ x, y }: FocusPoint, anim: Animated.Value) => ({
    height: 100,
    width: 100,
    borderWidth: 1,
    borderColor: '#fff',
    borderRadius: Units.small,
    shadowRadius: 3,
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowColor: '#fff',
    shadowOpacity: 1,
    backgroundColor: 'transparent',
    position: 'absolute',
    top: y - 50,
    left: x - 50,
    opacity: anim,
    transform: [
      {
        scale: anim.interpolate({
          inputRange: [0, 1],
          outputRange: [0.75, 1],
        }),
      },
    ],
  }),
};

// $FlowFixMe
@autobind
export class CameraFocusArea extends Component<Props, State> {
  state = {
    focusPoint: { x: 0, y: 0 },
  };
  anim: Animated.Value = new Animated.Value(0);
  touchableRef = React.createRef();

  isValidTouch(event: any): boolean {
    const touchableNodeHandle = findNodeHandle(this.touchableRef.current);
    return (
      !!event.nativeEvent && event.nativeEvent.target === touchableNodeHandle
    );
  }

  touchableOnPressIn(event: any) {
    if (!this.isValidTouch(event)) {
      return;
    }
    const { locationX, locationY } = event.nativeEvent;
    const focusPoint = {
      x: locationX,
      y: locationY,
    };
    this.setState({ focusPoint }, () => {
      this.animateFocusIn();
      this.props.onRequestFocus(focusPoint);
    });
  }

  touchableOnPressOut() {
    this.animateFocusOut();
  }

  animateFocusIn() {
    Animated.timing(this.anim, {
      toValue: 1,
      duration: 600,
      easing: Easing.bounce,
      useNativeDriver: true,
    }).start();
  }

  animateFocusOut() {
    Animated.timing(this.anim, {
      toValue: 0,
      duration: 600,
      easing: Easing.bounce,
      useNativeDriver: true,
    }).start();
  }

  render() {
    return (
      <TouchableWithoutFeedback
        ref={this.touchableRef}
        onPressIn={this.touchableOnPressIn}
        onPressOut={this.touchableOnPressOut}
      >
        <View style={[styles.container, this.props.style]}>
          <Animated.View
            style={styles.focusArea(this.state.focusPoint, this.anim)}
          />
        </View>
      </TouchableWithoutFeedback>
    );
  }
}
