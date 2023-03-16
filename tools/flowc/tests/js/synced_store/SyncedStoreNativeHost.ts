import * as typenames from "./SyncedStoreNativeHost-types.d";

import { syncedStore, getYjsValue, Y } from "@syncedstore/core";
import { WebrtcProvider } from "y-webrtc";

// Create your SyncedStore store
// We create a store which contains an array (myArray) and an object (myObject)

type Todo = { completed: boolean, title: string };

export const store = syncedStore({ myArray: [] as Todo[], fragment: "xml"});

// Create a document that syncs automatically using Y-WebRTC
const doc = getYjsValue(store);
export const webrtcProvider = (doc instanceof Y.Doc) ? new WebrtcProvider("syncedstore-plain", doc) : undefined;

export const disconnect = () => webrtcProvider.disconnect();
export const connect = () => webrtcProvider.connect();

