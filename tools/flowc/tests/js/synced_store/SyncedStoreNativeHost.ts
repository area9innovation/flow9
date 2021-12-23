import * as typenames from "./SyncedStoreNativeHost-types.d";

import { syncedStore, getYjsValue } from "@syncedstore/core";
import { WebrtcProvider } from "y-webrtc";

// Create your SyncedStore store
// We create a store which contains an array (myArray) and an object (myObject)

type Todo = { completed: boolean, title: string };

export const store = syncedStore({ myArray: [] as Todo[], fragment: "xml"});

// Create a document that syncs automatically using Y-WebRTC
const doc = getYjsValue(store);
export const webrtcProvider = new WebrtcProvider("syncedstore-plain", doc);

export const disconnect = () => webrtcProvider.disconnect();
export const connect = () => webrtcProvider.connect();

