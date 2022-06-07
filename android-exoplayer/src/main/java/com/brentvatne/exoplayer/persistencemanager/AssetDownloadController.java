package com.brentvatne.exoplayer.persistencemanager;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.SharedPreferences;
import androidx.annotation.Nullable;
import android.util.Log;
import android.widget.Toast;

import com.google.android.exoplayer2.DefaultRenderersFactory;
import com.google.android.exoplayer2.MediaItem;
import com.google.android.exoplayer2.database.DatabaseProvider;
import com.google.android.exoplayer2.database.StandaloneDatabaseProvider;
import com.google.android.exoplayer2.offline.Download;
import com.google.android.exoplayer2.offline.DownloadCursor;
import com.google.android.exoplayer2.offline.DownloadHelper;
import com.google.android.exoplayer2.offline.DownloadIndex;
import com.google.android.exoplayer2.offline.DownloadManager;
import com.google.android.exoplayer2.offline.DownloadRequest;
import com.google.android.exoplayer2.offline.DownloadService;
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector;
import com.google.android.exoplayer2.upstream.DataSource;
import com.google.android.exoplayer2.upstream.DefaultDataSource;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource;
import com.google.android.exoplayer2.upstream.HttpDataSource;
import com.google.android.exoplayer2.upstream.cache.Cache;
import com.google.android.exoplayer2.upstream.cache.CacheDataSource;
import com.google.android.exoplayer2.upstream.cache.NoOpCacheEvictor;
import com.google.android.exoplayer2.upstream.cache.SimpleCache;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.stream.Collectors;

public final class AssetDownloadController {
    private static final HashMap<Integer, HLSAsset.HLSAssetStatus> statusMap = new HashMap(){{
        put(Download.STATE_DOWNLOADING, HLSAsset.HLSAssetStatus.PENDING);
        put(Download.STATE_FAILED, HLSAsset.HLSAssetStatus.FAILED);
        put(Download.STATE_COMPLETED, HLSAsset.HLSAssetStatus.FINISHED);
        put(Download.STATE_QUEUED, HLSAsset.HLSAssetStatus.IDLE);
    }};

    public static final String DOWNLOAD_NOTIFICATION_CHANNEL_ID = "download_channel";
    private static final String DOWNLOAD_CONTENT_DIRECTORY = "downloads";
    private static final String DOWNLOAD_SHARED_PREFS = "downloads";
    private static final String TAG = "AssetDownloadController";

    @SuppressLint("StaticFieldLeak")
    private static Context context;
    private static DataSource.Factory dataSourceFactory;
    private static HttpDataSource.Factory httpDataSourceFactory;
    private static DatabaseProvider databaseProvider;
    private static File downloadDirectory;
    private static Cache downloadCache;
    private static DownloadManager downloadManager;
    private static AssetDownloadNotificationHelper downloadNotificationHelper;

    private static DownloadIndex downloadIndex;
    public static DefaultTrackSelector.Parameters trackSelectorParameters;

    public static HashMap<String, Download> downloads = new HashMap<>();
    public static HashMap<String, HLSAsset> assets = new HashMap<>();

    private static SharedPreferences sharedPreferences;

    private static final ArrayList<Runnable> listeners = new ArrayList<>();

    public static int downloadsPerBatchCount = 0;
    public static int downloadsPerBatchCountRemaining = 0;

    public static synchronized void init(Context appContext) {
        if (context != null) {
            Log.d(TAG, "AssetDownloadController is already initialized");
            return;
        }

        context = appContext.getApplicationContext();

        sharedPreferences = context.getSharedPreferences("AssetDownloadData", Context.MODE_PRIVATE);

        httpDataSourceFactory = new DefaultHttpDataSource.Factory();
        databaseProvider = new StandaloneDatabaseProvider(context);
        downloadDirectory = new File(
                context.getFilesDir(),
                DOWNLOAD_CONTENT_DIRECTORY
        );
        downloadCache = new SimpleCache(
                downloadDirectory,
                new NoOpCacheEvictor(),
                databaseProvider
        );
        dataSourceFactory = buildReadOnlyCacheDataSource(
                new DefaultDataSource.Factory(context, httpDataSourceFactory),
                downloadCache
        );
        downloadManager = new DownloadManager(
                context,
                databaseProvider,
                downloadCache,
                httpDataSourceFactory,
                Executors.newFixedThreadPool(6)
        );
        downloadManager.addListener(new DownloadManagerListener());
        downloadManager.setMaxParallelDownloads(3);
        downloadIndex = downloadManager.getDownloadIndex();

        AssetDownloadService.addProgressListener(AssetDownloadController::onProgressChanged);

        loadDownloads();
    }

    // Actions

    public static void downloadAsset(HLSAsset asset, int bitrate) {

        trackSelectorParameters = DownloadHelper
                .getDefaultTrackSelectorParameters(context)
                .buildUpon()
                .setForceHighestSupportedBitrate(false)
                .setMinVideoBitrate(bitrate - bitrate/3)
                .setMaxVideoBitrate(bitrate + bitrate/3)
                .setExceedVideoConstraintsIfNecessary(true)
                .build();

        MediaItem mediaItem = asset.getMediaItemForDownload();

        DownloadHelper downloadHelper = DownloadHelper.forMediaItem(
                context,
                mediaItem,
                new DefaultRenderersFactory(context),
                dataSourceFactory
        );


        downloadHelper.prepare(new DownloadHelper.Callback() {
            @Override
            public void onPrepared(DownloadHelper helper) {
                Log.d(TAG, "Download prepared");

                for (int i = 0; i < helper.getPeriodCount(); i++) {
                    helper.clearTrackSelections(i);
                }


                helper.addTrackSelection(0, trackSelectorParameters);

                DownloadRequest request = helper
                        .getDownloadRequest(
                                asset.id,
                                null
                        );


                if (request.streamKeys.isEmpty()) {
                    Log.wtf(TAG, "No tracks selected, this will cause all tracks to be downloaded. Bailing out");
                    Toast.makeText(
                            context,
                            "Oops, something is wrong with this video, it cannot be downloaded at the moment, sorry!",
                            Toast.LENGTH_LONG
                    ).show();
                    return;
                }

                Log.d(TAG, "stream keys size:" + request.streamKeys.size());
                asset.streamKeys = request.streamKeys;
                saveAssetData(asset);
                downloadsPerBatchCount++;
                downloadsPerBatchCountRemaining++;

                DownloadService.sendAddDownload(
                        context,
                        AssetDownloadService.class,
                        request,
                        false
                );
            }

            @Override
            public void onPrepareError(DownloadHelper helper, IOException e) {
                Log.w(TAG, "Something happened");
            }
        });
    }

    public static void deleteAsset(HLSAsset asset) {
        Download download = findDownloadByAsset(asset);
        if (download != null && download.state != Download.STATE_FAILED) {
            DownloadService.sendRemoveDownload(
                    context, AssetDownloadService.class, download.request.id, false);
        }
    }

    public static void cancelAssetDownload(HLSAsset asset) {
        Download download = findDownloadByAsset(asset);
        if (download != null && download.state != Download.STATE_FAILED) {
            DownloadService.sendRemoveDownload(
                    context, AssetDownloadService.class, download.request.id, false);
        }
    }

    // Helpers

    @Nullable
    public static HLSAsset findAssetById(String id) {
        return assets.get(id);
    }

    @Nullable
    public static Download findDownloadByAsset(HLSAsset asset) {
        return downloads.get(asset.id);
    }

    @Nullable
    public static HLSAsset findAssetByDownload(Download download) {
        return assets.get(download.request.id);
    }

    public static List<Download> getPendingDownloads() {
        return downloads
                .values()
                .stream()
                .filter(dl -> dl.state != Download.STATE_COMPLETED)
                .collect(Collectors.toList());
    }

    // Data persistence

    private static void runListeners() {
        for (Runnable listener : listeners) {
            listener.run();
        }
    }

    private static void saveAssetData(HLSAsset asset) {
        assets.put(asset.id, asset);
        Gson gson = new Gson();
        String json = gson.toJson(assets);
        sharedPreferences
                .edit()
                .putString(DOWNLOAD_SHARED_PREFS, json)
                .apply();

        runListeners();
    }

    private static void deleteAssetData(HLSAsset asset) {
        assets.remove(asset.id);
        Gson gson = new Gson();
        String json = gson.toJson(assets);
        sharedPreferences
                .edit()
                .putString(DOWNLOAD_SHARED_PREFS, json)
                .apply();

        runListeners();
    }

    private static void loadDownloads() {
        try {
            String json = sharedPreferences.getString(DOWNLOAD_SHARED_PREFS,"");
            if (json == "") {
                return;
            }
            Log.d(TAG,json);
            Gson gson = new Gson();
            HashMap<String, HLSAsset> savedAssets = new HashMap<>();
            savedAssets = gson.fromJson(json, new TypeToken<HashMap<String, HLSAsset>>(){}.getType());
            if (savedAssets != null) {
                assets = (HashMap<String, HLSAsset>) savedAssets;
            }
        } catch (Exception e) {
            Log.w(TAG, "Failed to restore saved assets data", e);
        }

        try (DownloadCursor loadedDownloads = downloadIndex.getDownloads()) {
            while (loadedDownloads.moveToNext()) {
                Download download = loadedDownloads.getDownload();
                downloads.put(download.request.id, download);
                HLSAsset downloadedAsset = findAssetByDownload(download);
                if (downloadedAsset != null) {
                    if (statusMap.get(download.state) != null) {
                        downloadedAsset.status = statusMap.get(download.state);
                        downloadedAsset.progress = download.getPercentDownloaded() / 100;
                        saveAssetData(downloadedAsset);
                    }
                }
            }
        } catch (IOException e) {
            Log.w(TAG, "Failed to query downloads", e);
        }
    }

    // Progress listener (called by AssetDownloadService)

    private static void onProgressChanged(List<Download> progressDownloads) {
        for (Download download: progressDownloads) {
            HLSAsset asset = findAssetByDownload(download);
            if (asset == null) {
                Log.wtf(TAG, "download changed: download doesn't have a matching asset");
                return;
            }
            Log.d(TAG, "downloaded:" + download.getBytesDownloaded() / 1000 / 1000 + " MB");
            asset.size = download.getBytesDownloaded();
            asset.progress = download.getPercentDownloaded() / 100;
            saveAssetData(asset);
            downloads.put(download.request.id, download);
        }
    }


    // Download change/remove listeners

    private static class DownloadManagerListener implements DownloadManager.Listener {
        @Override
        public void onDownloadChanged(
                DownloadManager downloadManager,
                Download download,
                Exception finalException
        ) {
            HLSAsset asset = findAssetByDownload(download);
            if (asset == null) {
                Log.wtf(TAG, "download changed: download doesn't have a matching asset");
                return;
            }
            HLSAsset.HLSAssetStatus assetStatus = statusMap.get(download.state);
            if (assetStatus != null) {
                asset.status = assetStatus;
                if (assetStatus == HLSAsset.HLSAssetStatus.FINISHED) {
                    downloadsPerBatchCountRemaining--;
                }
            }
            asset.size = download.getBytesDownloaded();
            asset.progress = download.getPercentDownloaded() / 100;
            saveAssetData(asset);
            downloads.put(download.request.id, download);
        }

        @Override
        public void onDownloadRemoved(DownloadManager downloadManager, Download download) {
            HLSAsset asset = findAssetByDownload(download);
            if (asset == null) {
                Log.wtf(TAG, "download removed: download doesn't have a matching asset");
                return;
            }
            deleteAssetData(asset);
            downloads.remove(download.request.id);
        }


    }

    public static void addListener(Runnable listener) {
        listeners.add(listener);
    }


    // Getters for DownloadService

    public static synchronized DownloadManager getDownloadManager(Context context) {
        if (downloadManager == null) {
            init(context);
        }
        return downloadManager;
    }

    public static synchronized AssetDownloadNotificationHelper getDownloadNotificationHelper(
            Context context) {
        if (downloadNotificationHelper == null) {
            downloadNotificationHelper =
                    new AssetDownloadNotificationHelper(context, DOWNLOAD_NOTIFICATION_CHANNEL_ID);
        }
        return downloadNotificationHelper;
    }

    // Misc

    private static CacheDataSource.Factory buildReadOnlyCacheDataSource(
            DataSource.Factory upstreamFactory, Cache cache) {
        return new CacheDataSource.Factory()
                .setCache(cache)
                .setUpstreamDataSourceFactory(upstreamFactory)
                .setCacheWriteDataSinkFactory(null)
                .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR);
    }

    public static DataSource.Factory getDataSourceFactory(){
        return dataSourceFactory;
    }

}