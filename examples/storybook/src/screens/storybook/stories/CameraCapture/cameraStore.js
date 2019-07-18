// @flow
import { createStore, applyMiddleware } from 'redux';
import * as storage from 'redux-storage';
import immutableMerger from 'redux-storage-merger-immutablejs';
import thunkMiddleware from 'redux-thunk';
import { createLogger } from 'redux-logger';
import { reducer } from '@jonbrennecke/react-native-camera';

const isProduction = process.env.NODE_ENV === 'production';

const loggerMiddleware = createLogger({
  collapsed: (getState, action) => !action.error,
});

const rootReducer = storage.reducer(reducer, immutableMerger);

const middleware = isProduction
  ? applyMiddleware(thunkMiddleware)
  : applyMiddleware(thunkMiddleware, loggerMiddleware);

export const createReduxStore = () => {
  return createStore(rootReducer, middleware);
};
