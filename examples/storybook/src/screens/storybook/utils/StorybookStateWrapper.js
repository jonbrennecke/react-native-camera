// @flow
import { PureComponent } from 'react';

import type { Element } from 'react';

export type StorybookStateWrapperProps<S: Object> = {
  initialState: S,
  onMount?: (data: ?S, setState: (?S) => void) => void,
  render: (data: ?S, setState: (?S) => void) => ?Element<*>,
};

export type StorybookStateWrapperState<S: Object> = S;

export class StorybookStateWrapper<S: Object> extends PureComponent<
  StorybookStateWrapperProps<S>,
  StorybookStateWrapperState<S>
> {
  constructor(props: StorybookStateWrapperProps<S>) {
    super(props);
    this.state = props.initialState;
  }

  componentDidMount() {
    if (this.props.onMount) {
      this.props.onMount(this.state, state => this.setState(state));
    }
  }

  render() {
    // $FlowFixMe
    return this.props.render(this.state, state => this.setState(state)) || null;
  }
}
