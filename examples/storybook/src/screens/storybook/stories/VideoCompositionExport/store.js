// @flow
import { createStore, applyMiddleware, combineReducers } from 'redux';
import * as storage from 'redux-storage';
import immutableMerger from 'redux-storage-merger-immutablejs';
import thunkMiddleware from 'redux-thunk';
import { createLogger } from 'redux-logger';
import { reducer as cameraReducer } from '@jonbrennecke/react-native-camera';
import { reducer as mediaReducer } from '@jonbrennecke/react-native-media';

const isProduction = process.env.NODE_ENV === 'production';

const loggerMiddleware = createLogger({
  collapsed: (getState, action) => !action.error,
});

const reducer = combineReducers({
  media: mediaReducer,
  camera: cameraReducer,
});

const rootReducer = storage.reducer(reducer, immutableMerger);

const middleware = isProduction
  ? applyMiddleware(thunkMiddleware)
  : applyMiddleware(thunkMiddleware, loggerMiddleware);

export const createReduxStore = () =>
  createStore(rootReducer, middleware);
