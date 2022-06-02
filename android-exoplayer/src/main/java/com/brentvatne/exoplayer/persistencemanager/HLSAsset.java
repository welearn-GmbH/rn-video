package com.brentvatne.exoplayer.persistencemanager;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableMap;
import com.google.android.exoplayer2.MediaItem;
import com.google.android.exoplayer2.offline.StreamKey;
import com.google.android.exoplayer2.util.MimeTypes;

import java.util.List;

public class HLSAsset {
    String id;
    String hlsUrl;
    float progress = 0;
    float size = 0;
    HLSAssetStatus status = HLSAssetStatus.IDLE;
    List<StreamKey> streamKeys;

    HLSAsset(String id, String hlsUrl) {
        this.hlsUrl = hlsUrl;
        this.id = id;
    }

    MediaItem getMediaItemForDownload() {
        MediaItem item = new MediaItem.Builder()
                .setUri(hlsUrl)
                .setMimeType(MimeTypes.APPLICATION_M3U8)
                .build();

        return item;
    }

    MediaItem getMediaItem() {
        MediaItem item = new MediaItem.Builder()
                .setUri(hlsUrl)
                .setMimeType(MimeTypes.APPLICATION_M3U8)
                .setStreamKeys(streamKeys)
                .build();

        return item;
    }

    public WritableMap getDataForJS() {
        WritableMap map = Arguments.createMap();
        
        map.putString("id",id);
        map.putString("hlsUrl",hlsUrl);
        map.putString("status",status.name());
        map.putDouble("progress",progress);
        map.putDouble("size",size);
        return map;
    }


    public enum HLSAssetStatus {
        IDLE,
        PENDING,
        FINISHED,
        FAILED
    }
}