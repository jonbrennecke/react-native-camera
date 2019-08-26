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

import type { Element } from 'react';
import type { Style } from '../../types/react';

type FocusPoint = { x: number, y: number };

type Props = {
  style?: ?Style,
  onRequestFocus: FocusPoint => void,
  renderFocusArea: (
    focusPosition: Animated.ValueXY,
    touchAnim: Animated.Value,
    focusPoint: FocusPoint
  ) => Element<*>,
};

type State = {
  focusPoint: FocusPoint,
};

const styles = {
  container: {},
};

// $FlowFixMe
@autobind
export class CameraFocusArea extends Component<Props, State> {
  state = {
    focusPoint: { x: 0, y: 0 },
  };
  positionAnim = new Animated.ValueXY();
  touchAnim = new Animated.Value(0);
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
      this.animateTouchIn(focusPoint);
      this.props.onRequestFocus(focusPoint);
    });
  }

  touchableOnPressOut() {
    this.animateTouchOut();
  }

  animateTouchIn(focusPoint: FocusPoint) {
    Animated.timing(this.positionAnim, {
      toValue: focusPoint,
      easing: Easing.linear,
      duration: 100,
      useNativeDriver: true,
    }).start();
    Animated.timing(this.touchAnim, {
      toValue: 1,
      duration: 300,
      easing: Easing.inOut(Easing.quad),
      useNativeDriver: true,
    }).start();
  }

  animateTouchOut() {
    Animated.timing(this.touchAnim, {
      toValue: 0,
      duration: 300,
      easing: Easing.inOut(Easing.quad),
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
          {this.props.renderFocusArea(
            this.positionAnim,
            this.touchAnim,
            this.state.focusPoint
          )}
        </View>
      </TouchableWithoutFeedback>
    );
  }
}
