package com.brentvatne.exoplayer.persistencemanager;

import android.app.Notification;
import android.app.PendingIntent;
import android.content.Context;

import androidx.annotation.DrawableRes;
import androidx.annotation.Nullable;
import androidx.annotation.StringRes;
import androidx.core.app.NotificationCompat;

import com.google.android.exoplayer2.C;
import com.google.android.exoplayer2.offline.Download;
import com.google.android.exoplayer2.scheduler.Requirements;

import java.util.List;

/** Helper for creating download notifications. */
public final class AssetDownloadNotificationHelper {

    private static final @StringRes
    int NULL_STRING_ID = 0;

    private final NotificationCompat.Builder notificationBuilder;

    /**
     * @param context A context.
     * @param channelId The id of the notification channel to use.
     */
    public AssetDownloadNotificationHelper(Context context, String channelId) {
        this.notificationBuilder =
                new NotificationCompat.Builder(context.getApplicationContext(), channelId);
    }


    /**
     * Returns a progress notification for the given downloads.
     *
     * @param context A context.
     * @param smallIcon A small icon for the notification.
     * @param contentIntent An optional content intent to send when the notification is clicked.
     * @param message An optional message to display on the notification.
     * @param downloads The downloads.
     * @param notMetRequirements Any requirements for downloads that are not currently met.
     * @return The notification.
     */
    public Notification buildProgressNotification(
            Context context,
            @DrawableRes int smallIcon,
            @Nullable PendingIntent contentIntent,
            String message,
            List<Download> downloads,
            @Requirements.RequirementFlags int notMetRequirements) {
        float totalPercentage = 0;
        int downloadTaskCount = 0;
        boolean allDownloadPercentagesUnknown = true;
        boolean haveDownloadedBytes = false;
        boolean haveDownloadingTasks = false;
        boolean haveQueuedTasks = false;
        boolean haveRemovingTasks = false;
        String title = "";
        for (int i = 0; i < downloads.size(); i++) {
            Download download = downloads.get(i);
            switch (download.state) {
                case Download.STATE_REMOVING:
                    haveRemovingTasks = true;
                    break;
                case Download.STATE_QUEUED:
                    haveQueuedTasks = true;
                    break;
                case Download.STATE_RESTARTING:
                case Download.STATE_DOWNLOADING:
                    haveDownloadingTasks = true;
                    float downloadPercentage = download.getPercentDownloaded();
                    if (downloadPercentage != C.PERCENTAGE_UNSET) {
                        allDownloadPercentagesUnknown = false;
                        totalPercentage += downloadPercentage;
                    }
                    haveDownloadedBytes |= download.getBytesDownloaded() > 0;
                    downloadTaskCount++;
                    break;
                // Terminal states aren't expected, but if we encounter them we do nothing.
                case Download.STATE_STOPPED:
                case Download.STATE_COMPLETED:
                case Download.STATE_FAILED:
                default:
                    break;
            }
        }

        boolean showProgress = true;
        if (haveDownloadingTasks) {
            title = "Downloading " +
                    (
                            AssetDownloadController.downloadsPerBatchCount -
                            AssetDownloadController.downloadsPerBatchCountRemaining + 1
                    ) +
                    " of " +
                    AssetDownloadController.downloadsPerBatchCount +
                    " video" +
                    (
                            AssetDownloadController.downloadsPerBatchCount > 1 ? "s" : ""
                    );
        } else if (haveQueuedTasks && notMetRequirements != 0) {
            showProgress = false;
            title = "Waiting to start downloads";
        } else if (haveRemovingTasks) {
            title = "Removing downloads";
        }

        int maxProgress = 0;
        int currentProgress = 0;
        boolean indeterminateProgress = false;
        if (showProgress) {
            maxProgress = 100;
            if (haveDownloadingTasks) {
                currentProgress = (int) (totalPercentage / downloadTaskCount);
                indeterminateProgress = allDownloadPercentagesUnknown && haveDownloadedBytes;
            } else {
                indeterminateProgress = true;
            }
        }

        return buildNotification(
                context,
                smallIcon,
                contentIntent,
                message,
                title,
                maxProgress,
                currentProgress,
                indeterminateProgress,
                /* ongoing= */ true,
                /* showWhen= */ false);
    }

    /**
     * Returns a notification for a completed download.
     *
     * @param context A context.
     * @param smallIcon A small icon for the notifications.
     * @param contentIntent An optional content intent to send when the notification is clicked.
     * @param message An optional message to display on the notification.
     * @return The notification.
     */
    public Notification buildDownloadCompletedNotification(
            Context context,
            @DrawableRes int smallIcon,
            @Nullable PendingIntent contentIntent,
            @Nullable String message) {
        return buildEndStateNotification(context, smallIcon, contentIntent, message, AssetDownloadController.downloadsPerBatchCount + " videos downloaded");
    }

    /**
     * Returns a notification for a failed download.
     *
     * @param context A context.
     * @param smallIcon A small icon for the notifications.
     * @param contentIntent An optional content intent to send when the notification is clicked.
     * @param message An optional message to display on the notification.
     * @return The notification.
     */
    public Notification buildDownloadFailedNotification(
            Context context,
            @DrawableRes int smallIcon,
            @Nullable PendingIntent contentIntent,
            @Nullable String message) {
        return buildEndStateNotification(context, smallIcon, contentIntent, message, "Downloads failed");
    }

    private Notification buildEndStateNotification(
            Context context,
            @DrawableRes int smallIcon,
            @Nullable PendingIntent contentIntent,
            @Nullable String message,
            String title) {
        return buildNotification(
                context,
                smallIcon,
                contentIntent,
                message,
                title,
                /* maxProgress= */ 0,
                /* currentProgress= */ 0,
                /* indeterminateProgress= */ false,
                /* ongoing= */ false,
                /* showWhen= */ true);
    }

    private Notification buildNotification(
            Context context,
            @DrawableRes int smallIcon,
            @Nullable PendingIntent contentIntent,
            @Nullable String message,
            String title,
            int maxProgress,
            int currentProgress,
            boolean indeterminateProgress,
            boolean ongoing,
            boolean showWhen) {
        notificationBuilder.setSmallIcon(smallIcon);
        notificationBuilder.setContentTitle(title);
        notificationBuilder.setContentIntent(contentIntent);
        notificationBuilder.setStyle(
                message == null ? null : new NotificationCompat.BigTextStyle().bigText(message));
        notificationBuilder.setProgress(maxProgress, currentProgress, indeterminateProgress);
        notificationBuilder.setOngoing(ongoing);
        notificationBuilder.setShowWhen(showWhen);
        return notificationBuilder.build();
    }
}
