
export const enum HlsAssetStatus {
    IDLE = 'IDLE',
    PENDING = 'PENDING',
    FINISHED = 'FINISHED',
    FAILED = 'FAILED',
}

export interface HlsAsset {
    id: string;
    hlsUrl: string;
    progress: number;
    status: HlsAssetStatus;
    size: number;
}
