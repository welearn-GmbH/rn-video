
import { NativeEventEmitter, NativeModules } from 'react-native';
import type { HlsAsset } from './types/persistence';

const downloadHlsAsset = async (id: string, hlsUrl: string, bitrate: number) => {
    return await NativeModules.AssetPersistenceManager.downloadStream(id, hlsUrl, bitrate)
}

const cancelHlsAssetDownload = async (id: string) => {
    return await NativeModules.AssetPersistenceManager.cancelDownload(id)
}
 
const deleteHlsAsset = async (id: string) => {
    return await NativeModules.AssetPersistenceManager.deleteAsset(id)
}

const getHlsAssets = async () => {
    return await NativeModules.AssetPersistenceManager.getHLSAssetsForJS()
}

const hlsAssetListeners: ((assets: HlsAsset[]) => void)[] = [];

const addHlsAssetsListener = (listener: (assets: HlsAsset[]) => void) => {
    hlsAssetListeners.push(listener);
    return () => {
        hlsAssetListeners.splice(hlsAssetListeners.indexOf(listener), 1);
    }
}

// AssetPersistenceEventEmitter is undefined on Android, which is fine
const eventEmitter = new NativeEventEmitter(NativeModules.AssetPersistenceEventEmitter || NativeModules.AssetPersistenceManager);

eventEmitter.addListener("hlsDownloads", (assets: HlsAsset[]) => {
    hlsAssetListeners.forEach((listener) => {
        listener(assets);
    });
});

export {
    addHlsAssetsListener, cancelHlsAssetDownload,
    deleteHlsAsset, downloadHlsAsset, getHlsAssets
};
