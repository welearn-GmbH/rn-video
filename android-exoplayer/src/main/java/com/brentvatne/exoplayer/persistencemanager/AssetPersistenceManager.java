package com.brentvatne.exoplayer.persistencemanager;

import android.net.Uri;
import androidx.annotation.Nullable;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.google.android.exoplayer2.MediaItem;
import com.google.android.exoplayer2.offline.DownloadService;
import com.google.android.exoplayer2.upstream.DataSource;

public class AssetPersistenceManager extends ReactContextBaseJavaModule  {
    AssetDownloadController assetDownloadController;
    ReactApplicationContext reactContext;
    static String hlsDownloadsJSEventName = "hlsDownloads";

    private void sendEvent(String eventName, @Nullable Object params) {
        if (!reactContext.hasActiveCatalystInstance()) {
            return;
        }
        reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
    }

    public AssetPersistenceManager(ReactApplicationContext appContext) {
        super(appContext);
        reactContext = appContext;

        AssetDownloadController.init(appContext);
        AssetDownloadController.addListener(this::onDownloadsChanged);

        try {
            DownloadService.start(appContext, AssetDownloadService.class);
        } catch (IllegalStateException e) {
            DownloadService.startForeground(appContext, AssetDownloadService.class);
        }
    }

    @Override
    public String getName() {
        return "AssetPersistenceManager";
    }

    @ReactMethod
    public void downloadStream(String id, String hlsUrl, int bitrate) {
        HLSAsset existingAsset = AssetDownloadController.findAssetById(id);
        if (existingAsset != null) {
            return;
        }
        HLSAsset asset = new HLSAsset(id, hlsUrl);
        AssetDownloadController.downloadAsset(asset, bitrate);
    }

    @ReactMethod
    public void deleteAsset(String id) {
        HLSAsset asset = AssetDownloadController.findAssetById(id);
        if (asset == null) {
            return;
        }
        AssetDownloadController.deleteAsset(asset);
    }
    
    @ReactMethod
    public void cancelDownload(String id) {
        HLSAsset asset = AssetDownloadController.findAssetById(id);
        if (asset == null) {
            return;
        }
        AssetDownloadController.cancelAssetDownload(asset);
    }

    @ReactMethod
    public void getHLSAssetsForJS(Promise promise) {
        promise.resolve(collectHLSAssetsForJS());
    }

    public void sendHLSAssetsToJS(){
        sendEvent(hlsDownloadsJSEventName, collectHLSAssetsForJS());
    }

    private WritableArray collectHLSAssetsForJS(){
        WritableArray assets = Arguments.createArray();
        for (HLSAsset asset: AssetDownloadController.assets.values()) {
            assets.pushMap(asset.getDataForJS());
        }
        return assets;
    }

    static public MediaItem mediaItemForUri(Uri uri) {
        HLSAsset matchingAsset = null;
        for (HLSAsset asset: AssetDownloadController.assets.values()) {
            if (Uri.parse(asset.hlsUrl).equals(uri)) {
                matchingAsset = asset;
                break;
            }
        }
        if (matchingAsset != null) {
            return matchingAsset.getMediaItem();
        }
        return MediaItem.fromUri(uri);
    }

    static public DataSource.Factory getDataSourceFactory() {
        return AssetDownloadController.getDataSourceFactory();
    }

    private void onDownloadsChanged() {
        sendHLSAssetsToJS();
    }
}
