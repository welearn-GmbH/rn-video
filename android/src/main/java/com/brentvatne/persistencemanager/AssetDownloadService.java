package com.brentvatne.exoplayer.persistencemanager;

import android.app.Notification;
import android.content.Context;

import androidx.annotation.Nullable;

import com.brentvatne.react.R;
import androidx.media3.exoplayer.offline.Download;
import androidx.media3.exoplayer.offline.DownloadManager;
import androidx.media3.exoplayer.offline.DownloadService;
import androidx.media3.exoplayer.scheduler.PlatformScheduler;
import androidx.media3.exoplayer.scheduler.Scheduler;
import androidx.media3.common.util.NotificationUtil;
import androidx.media3.common.util.Util;

import com.brentvatne.exoplayer.persistencemanager.AssetDownloadController;
import com.brentvatne.exoplayer.persistencemanager.AssetDownloadNotificationHelper;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;
import java.util.stream.Collectors;

public class AssetDownloadService extends DownloadService {

    private static final int JOB_ID = 1;
    private static final int FOREGROUND_NOTIFICATION_ID = 1;
    private static final String DOWNLOAD_NOTIFICATION_CHANNEL_ID = "download_channel";
    private static final ArrayList<Consumer<List<Download>>> listeners = new ArrayList<>();

    public AssetDownloadService() {
        super(
                FOREGROUND_NOTIFICATION_ID,
                DEFAULT_FOREGROUND_NOTIFICATION_UPDATE_INTERVAL,
                DOWNLOAD_NOTIFICATION_CHANNEL_ID,
                R.string.exo_download_notification_channel_name,
                0);

    }

    public static void addProgressListener(Consumer<List<Download>> listener) {
        listeners.add(listener);
    }

    @Override
    protected DownloadManager getDownloadManager() {
        DownloadManager downloadManager =
                AssetDownloadController.getDownloadManager(this);
        AssetDownloadNotificationHelper downloadNotificationHelper =
                AssetDownloadController.getDownloadNotificationHelper(this);
        downloadManager.addListener(
                new TerminalStateNotificationHelper(
                        this, downloadNotificationHelper, FOREGROUND_NOTIFICATION_ID
                )
        );
        return downloadManager;
    }

    @Nullable
    @Override
    protected Scheduler getScheduler() {
        return Util.SDK_INT >= 21 ? new PlatformScheduler(this, JOB_ID) : null;
    }

    @Override
    protected Notification getForegroundNotification(List<Download> downloads, int notMetRequirements) {
        for (Consumer<List<Download>> listener : listeners) {
            listener.accept(downloads);
        }
        return AssetDownloadController.getDownloadNotificationHelper(this)
                .buildProgressNotification(
                        this,
                        R.drawable.ic_download,
                        null,
                        null,
                        downloads,
                        notMetRequirements);
    }

    /**
     * Creates and displays notifications for downloads when they complete.
     *
     * <p>This helper will outlive the lifespan of a single instance of {@link AssetDownloadService}.
     * It is static to avoid leaking the first {@link AssetDownloadService} instance.
     */
    private static final class TerminalStateNotificationHelper implements DownloadManager.Listener {

        private final Context context;
        private final AssetDownloadNotificationHelper notificationHelper;

        private int notificationId;

        public TerminalStateNotificationHelper(
                Context context, AssetDownloadNotificationHelper notificationHelper, int foregroundNotificationId) {
            this.context = context.getApplicationContext();
            this.notificationHelper = notificationHelper;
            this.notificationId = foregroundNotificationId + 1;
        }

        @Override
        public void onDownloadChanged(
                DownloadManager downloadManager, Download download, @Nullable Exception finalException) {
            Notification notification;

            if (download.state != Download.STATE_COMPLETED) {
                return;
            }

            Boolean allCompleted = true;

            List<Download> otherDownloads = AssetDownloadController.downloads
                    .values()
                    .stream()
                    .filter(dl -> dl.request.id != download.request.id)
                    .collect(Collectors.toList());

            for (Download dl: otherDownloads
                 ) {
                if (dl.state != Download.STATE_COMPLETED) {
                    allCompleted = false;
                }
            }

            if (allCompleted) {
                notification =
                        notificationHelper.buildDownloadCompletedNotification(
                                context,
                                R.drawable.ic_download_done,
                                null,
                                null
                        );
                NotificationUtil.setNotification(context, notificationId, notification);
                AssetDownloadController.downloadsPerBatchCount = 0;
                AssetDownloadController.downloadsPerBatchCountRemaining = 0;
            }
        }
    }
}



