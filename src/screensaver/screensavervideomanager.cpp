#include "screensavervideomanager.h"
#include "core/settings.h"

#include <QStandardPaths>
#include <QDir>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>
#include <QRandomGenerator>
#include <QFileInfo>

const QString ScreensaverVideoManager::DEFAULT_CATALOG_URL =
    "https://decent-de1-media.s3.eu-north-1.amazonaws.com/pexels_videos_scaled/catalog.json";

// Old full-res URL for migration detection
const QString OLD_FULLRES_CATALOG_URL =
    "https://decent-de1-media.s3.eu-north-1.amazonaws.com/pexels_videos/catalog.json";

ScreensaverVideoManager::ScreensaverVideoManager(Settings* settings, QObject* parent)
    : QObject(parent)
    , m_settings(settings)
    , m_networkManager(new QNetworkAccessManager(this))
{
    // Initialize cache directory
    QString dataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    m_cacheDir = dataPath + "/screensaver_videos";
    QDir().mkpath(m_cacheDir);

    // Load settings
    m_enabled = m_settings->value("screensaver/enabled", true).toBool();
    m_catalogUrl = m_settings->value("screensaver/catalogUrl", DEFAULT_CATALOG_URL).toString();
    m_cacheEnabled = m_settings->value("screensaver/cacheEnabled", true).toBool();
    m_streamingFallbackEnabled = m_settings->value("screensaver/streamingFallback", true).toBool();
    m_maxCacheBytes = m_settings->value("screensaver/maxCacheBytes", 2LL * 1024 * 1024 * 1024).toLongLong();
    m_lastETag = m_settings->value("screensaver/lastETag", "").toString();

    // Migration: switch from full-res to scaled videos
    migrateToScaledVideos();

    // Load cache index
    loadCacheIndex();
    updateCacheUsedBytes();

    qDebug() << "[Screensaver] Initialized. Cache dir:" << m_cacheDir
             << "Cache used:" << (m_cacheUsedBytes / 1024 / 1024) << "MB"
             << "Enabled:" << m_enabled;

    // Auto-refresh catalog on startup if enabled (immediate start)
    if (m_enabled) {
        QTimer::singleShot(0, this, &ScreensaverVideoManager::refreshCatalog);
    }
}

ScreensaverVideoManager::~ScreensaverVideoManager()
{
    stopBackgroundDownload();
    saveCacheIndex();
}

void ScreensaverVideoManager::migrateToScaledVideos()
{
    // Check if user is still on the old full-res catalog URL
    if (m_catalogUrl != OLD_FULLRES_CATALOG_URL) {
        return;  // Already migrated or using custom URL
    }

    qDebug() << "[Screensaver] Migrating from full-res to scaled videos...";

    // Delete all cached full-res videos
    QDir cacheDir(m_cacheDir);
    QStringList cachedFiles = cacheDir.entryList(QStringList() << "*.mp4", QDir::Files);

    qint64 freedBytes = 0;
    for (const QString& file : cachedFiles) {
        QString filePath = m_cacheDir + "/" + file;
        QFileInfo fi(filePath);
        freedBytes += fi.size();
        QFile::remove(filePath);
        qDebug() << "[Screensaver] Deleted full-res cache file:" << file;
    }

    // Also delete the cache index file
    QFile::remove(m_cacheDir + "/cache_index.json");

    qDebug() << "[Screensaver] Cleared" << cachedFiles.size() << "full-res videos,"
             << (freedBytes / 1024 / 1024) << "MB freed";

    // Update to new scaled catalog URL
    m_catalogUrl = DEFAULT_CATALOG_URL;
    m_settings->setValue("screensaver/catalogUrl", m_catalogUrl);

    // Clear ETag to force fresh catalog fetch
    m_lastETag.clear();
    m_settings->setValue("screensaver/lastETag", "");

    qDebug() << "[Screensaver] Migration complete. Now using:" << m_catalogUrl;
}

// Property setters
void ScreensaverVideoManager::setEnabled(bool enabled)
{
    if (m_enabled != enabled) {
        m_enabled = enabled;
        m_settings->setValue("screensaver/enabled", enabled);
        emit enabledChanged();

        if (enabled && m_catalog.isEmpty()) {
            refreshCatalog();
        }
    }
}

void ScreensaverVideoManager::setCatalogUrl(const QString& url)
{
    if (m_catalogUrl != url) {
        m_catalogUrl = url;
        m_settings->setValue("screensaver/catalogUrl", url);
        m_lastETag.clear();  // Reset ETag when URL changes
        emit catalogUrlChanged();
    }
}

void ScreensaverVideoManager::setCacheEnabled(bool enabled)
{
    if (m_cacheEnabled != enabled) {
        m_cacheEnabled = enabled;
        m_settings->setValue("screensaver/cacheEnabled", enabled);
        emit cacheEnabledChanged();

        if (enabled && !m_catalog.isEmpty()) {
            startBackgroundDownload();
        } else {
            stopBackgroundDownload();
        }
    }
}

void ScreensaverVideoManager::setStreamingFallbackEnabled(bool enabled)
{
    if (m_streamingFallbackEnabled != enabled) {
        m_streamingFallbackEnabled = enabled;
        m_settings->setValue("screensaver/streamingFallback", enabled);
        emit streamingFallbackEnabledChanged();
    }
}

void ScreensaverVideoManager::setMaxCacheBytes(qint64 bytes)
{
    if (m_maxCacheBytes != bytes) {
        m_maxCacheBytes = bytes;
        m_settings->setValue("screensaver/maxCacheBytes", bytes);
        emit maxCacheBytesChanged();

        // Evict if over limit
        evictLruIfNeeded(0);
    }
}

// Catalog management
void ScreensaverVideoManager::refreshCatalog()
{
    if (m_isRefreshing) {
        qDebug() << "[Screensaver] Catalog refresh already in progress";
        return;
    }

    qDebug() << "[Screensaver] Refreshing catalog from:" << m_catalogUrl;

    m_isRefreshing = true;
    emit isRefreshingChanged();

    QNetworkRequest request{QUrl(m_catalogUrl)};
    request.setRawHeader("Accept", "application/json");

    // Use ETag for conditional request
    if (!m_lastETag.isEmpty()) {
        request.setRawHeader("If-None-Match", m_lastETag.toUtf8());
        qDebug() << "[Screensaver] Using ETag:" << m_lastETag;
    }

    m_catalogReply = m_networkManager->get(request);
    connect(m_catalogReply, &QNetworkReply::finished,
            this, &ScreensaverVideoManager::onCatalogReplyFinished);
}

void ScreensaverVideoManager::onCatalogReplyFinished()
{
    m_isRefreshing = false;
    emit isRefreshingChanged();

    if (!m_catalogReply) return;

    int statusCode = m_catalogReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    qDebug() << "[Screensaver] Catalog response status:" << statusCode;

    if (m_catalogReply->error() != QNetworkReply::NoError) {
        QString errorMsg = m_catalogReply->errorString();
        qWarning() << "[Screensaver] Catalog fetch error:" << errorMsg;
        emit catalogError(errorMsg);
        m_catalogReply->deleteLater();
        m_catalogReply = nullptr;
        return;
    }

    if (statusCode == 304) {
        // Not modified - but only valid if we already have catalog loaded
        if (!m_catalog.isEmpty()) {
            qDebug() << "[Screensaver] Catalog not modified (304), using cached" << m_catalog.size() << "videos";
            m_catalogReply->deleteLater();
            m_catalogReply = nullptr;
            return;
        }
        // Catalog is empty despite 304 - clear ETag and refetch
        qDebug() << "[Screensaver] Got 304 but catalog is empty, refetching...";
        m_lastETag.clear();
        m_settings->setValue("screensaver/lastETag", "");
        m_catalogReply->deleteLater();
        m_catalogReply = nullptr;
        refreshCatalog();  // Retry without ETag
        return;
    }

    // Store new ETag
    QString newETag = QString::fromUtf8(m_catalogReply->rawHeader("ETag"));
    if (!newETag.isEmpty()) {
        m_lastETag = newETag;
        m_settings->setValue("screensaver/lastETag", newETag);
        qDebug() << "[Screensaver] New ETag:" << newETag;
    }

    // Parse catalog
    QByteArray data = m_catalogReply->readAll();
    m_catalogReply->deleteLater();
    m_catalogReply = nullptr;

    parseCatalog(data);
}

void ScreensaverVideoManager::parseCatalog(const QByteArray& data)
{
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        QString errorMsg = "JSON parse error: " + parseError.errorString();
        qWarning() << "[Screensaver]" << errorMsg;
        emit catalogError(errorMsg);
        return;
    }

    QJsonArray array = doc.array();
    QList<VideoItem> newCatalog;

    for (const QJsonValue& val : array) {
        if (!val.isObject()) continue;

        VideoItem item = parseVideoItem(val.toObject());
        if (item.isValid()) {
            newCatalog.append(item);
        }
    }

    m_catalog = newCatalog;
    m_lastUpdatedUtc = QDateTime::currentDateTimeUtc();

    qDebug() << "[Screensaver] Catalog loaded:" << m_catalog.size() << "videos";
    emit catalogUpdated();

    // Start background download if caching is enabled
    if (m_cacheEnabled && !m_catalog.isEmpty()) {
        startBackgroundDownload();
    }
}

VideoItem ScreensaverVideoManager::parseVideoItem(const QJsonObject& obj)
{
    VideoItem item;

    item.id = obj["id"].toInt();
    item.durationSeconds = obj["duration_s"].toInt();
    item.author = obj["author"].toString();
    item.authorUrl = obj["author_url"].toString();
    item.sha256 = obj["sha256"].toString();
    item.bytes = obj["bytes"].toVariant().toLongLong();

    // Try different URL/path fields
    if (obj.contains("path")) {
        item.path = obj["path"].toString();
    } else if (obj.contains("url")) {
        item.absoluteUrl = obj["url"].toString();
    } else if (obj.contains("local_path")) {
        // Extract filename from local_path as fallback
        item.path = derivePathFromLocalPath(obj["local_path"].toString());
    } else if (obj.contains("filename")) {
        item.path = obj["filename"].toString();
    }

    // Source URL (pexels or generic)
    if (obj.contains("pexels_url")) {
        item.sourceUrl = obj["pexels_url"].toString();
    } else if (obj.contains("source_url")) {
        item.sourceUrl = obj["source_url"].toString();
    }

    if (!item.isValid()) {
        qWarning() << "[Screensaver] Skipping invalid catalog item, id:" << item.id
                   << "- no path or url found";
    }

    return item;
}

QString ScreensaverVideoManager::derivePathFromLocalPath(const QString& localPath)
{
    // Extract filename from a local path like "C:\...\pexels_videos\filename.mp4"
    // Note: QFileInfo doesn't understand Windows paths on Linux/Android, so manually extract
    QString filename = localPath;

    // Find last separator (either / or \)
    int lastSlash = localPath.lastIndexOf('/');
    int lastBackslash = localPath.lastIndexOf('\\');
    int lastSep = qMax(lastSlash, lastBackslash);

    if (lastSep >= 0) {
        filename = localPath.mid(lastSep + 1);
    }

    // URL-encode spaces and special chars (spaces become %20)
    return QString::fromUtf8(QUrl::toPercentEncoding(filename));
}

QString ScreensaverVideoManager::getBaseUrl() const
{
    // Extract base URL from catalog URL (directory containing catalog.json)
    QUrl url(m_catalogUrl);
    QString path = url.path();
    int lastSlash = path.lastIndexOf('/');
    if (lastSlash > 0) {
        url.setPath(path.left(lastSlash + 1));
    }
    return url.toString();
}

QString ScreensaverVideoManager::buildVideoUrl(const VideoItem& item) const
{
    if (!item.absoluteUrl.isEmpty()) {
        return item.absoluteUrl;
    }

    QString baseUrl = getBaseUrl();
    // Ensure proper URL joining
    if (!baseUrl.endsWith('/')) {
        baseUrl += '/';
    }

    // The path should already be URL-encoded from the catalog
    return baseUrl + item.path;
}

// Cache management
void ScreensaverVideoManager::loadCacheIndex()
{
    QString indexPath = m_cacheDir + "/cache_index.json";
    QFile file(indexPath);

    if (!file.open(QIODevice::ReadOnly)) {
        qDebug() << "[Screensaver] No cache index found, starting fresh";
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    if (!doc.isObject()) return;

    QJsonObject root = doc.object();
    for (auto it = root.begin(); it != root.end(); ++it) {
        int catalogId = it.key().toInt();
        QJsonObject cached = it.value().toObject();

        CachedVideo cv;
        cv.localPath = cached["localPath"].toString();
        cv.sha256 = cached["sha256"].toString();
        cv.bytes = cached["bytes"].toVariant().toLongLong();
        cv.lastAccessed = QDateTime::fromString(cached["lastAccessed"].toString(), Qt::ISODate);
        cv.catalogId = catalogId;

        // Verify file still exists
        if (QFile::exists(cv.localPath)) {
            m_cacheIndex[catalogId] = cv;
        }
    }

    qDebug() << "[Screensaver] Loaded cache index with" << m_cacheIndex.size() << "entries";
}

void ScreensaverVideoManager::saveCacheIndex()
{
    QString indexPath = m_cacheDir + "/cache_index.json";
    QFile file(indexPath);

    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "[Screensaver] Failed to save cache index";
        return;
    }

    QJsonObject root;
    for (auto it = m_cacheIndex.begin(); it != m_cacheIndex.end(); ++it) {
        QJsonObject cached;
        cached["localPath"] = it.value().localPath;
        cached["sha256"] = it.value().sha256;
        cached["bytes"] = it.value().bytes;
        cached["lastAccessed"] = it.value().lastAccessed.toString(Qt::ISODate);
        root[QString::number(it.key())] = cached;
    }

    file.write(QJsonDocument(root).toJson());
    file.close();
}

void ScreensaverVideoManager::updateCacheUsedBytes()
{
    qint64 total = 0;
    for (const CachedVideo& cv : m_cacheIndex) {
        total += cv.bytes;
    }
    if (m_cacheUsedBytes != total) {
        m_cacheUsedBytes = total;
        emit cacheUsedBytesChanged();
    }
}

void ScreensaverVideoManager::evictLruIfNeeded(qint64 neededBytes)
{
    while (m_cacheUsedBytes + neededBytes > m_maxCacheBytes && !m_cacheIndex.isEmpty()) {
        // Find LRU entry
        int lruId = -1;
        QDateTime oldestAccess = QDateTime::currentDateTimeUtc();

        for (auto it = m_cacheIndex.begin(); it != m_cacheIndex.end(); ++it) {
            if (it.value().lastAccessed < oldestAccess) {
                oldestAccess = it.value().lastAccessed;
                lruId = it.key();
            }
        }

        if (lruId >= 0) {
            CachedVideo cv = m_cacheIndex[lruId];
            qDebug() << "[Screensaver] Evicting LRU cache entry:" << cv.localPath
                     << "(" << (cv.bytes / 1024 / 1024) << "MB)";

            QFile::remove(cv.localPath);
            m_cacheIndex.remove(lruId);
            m_cacheUsedBytes -= cv.bytes;
        } else {
            break;
        }
    }

    emit cacheUsedBytesChanged();
    saveCacheIndex();
}

QString ScreensaverVideoManager::getCachePath(const VideoItem& item) const
{
    // Use id + sha256 prefix for unique filename
    QString sha256Prefix = item.sha256.left(8);
    if (sha256Prefix.isEmpty()) {
        sha256Prefix = QString::number(item.id);
    }
    return m_cacheDir + "/" + QString::number(item.id) + "_" + sha256Prefix + ".mp4";
}

bool ScreensaverVideoManager::isVideoCached(const VideoItem& item) const
{
    if (!m_cacheIndex.contains(item.id)) {
        return false;
    }

    const CachedVideo& cv = m_cacheIndex[item.id];

    // Verify file exists
    if (!QFile::exists(cv.localPath)) {
        return false;
    }

    // Verify SHA256 if available
    if (!item.sha256.isEmpty() && cv.sha256 != item.sha256) {
        return false;
    }

    return true;
}

bool ScreensaverVideoManager::verifySha256(const QString& filePath, const QString& expectedHash) const
{
    if (expectedHash.isEmpty()) {
        return true;  // No hash to verify
    }

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        return false;
    }

    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(&file);
    file.close();

    QString actualHash = hash.result().toHex();
    bool match = (actualHash.toLower() == expectedHash.toLower());

    if (!match) {
        qWarning() << "[Screensaver] SHA256 mismatch for" << filePath
                   << "expected:" << expectedHash << "actual:" << actualHash;
    }

    return match;
}

void ScreensaverVideoManager::clearCache()
{
    qDebug() << "[Screensaver] Clearing cache";

    stopBackgroundDownload();

    // Delete all cached files
    for (const CachedVideo& cv : m_cacheIndex) {
        QFile::remove(cv.localPath);
    }

    m_cacheIndex.clear();
    m_cacheUsedBytes = 0;
    saveCacheIndex();

    emit cacheUsedBytesChanged();
}

// Download management
void ScreensaverVideoManager::startBackgroundDownload()
{
    if (m_isDownloading || !m_cacheEnabled) {
        return;
    }

    queueAllVideosForDownload();

    if (!m_downloadQueue.isEmpty()) {
        qDebug() << "[Screensaver] Starting background download of" << m_downloadQueue.size() << "videos";
        processDownloadQueue();
    }
}

void ScreensaverVideoManager::stopBackgroundDownload()
{
    m_downloadQueue.clear();

    if (m_downloadReply) {
        m_downloadReply->abort();
        m_downloadReply->deleteLater();
        m_downloadReply = nullptr;
    }

    if (m_downloadFile) {
        m_downloadFile->close();
        m_downloadFile->remove();
        delete m_downloadFile;
        m_downloadFile = nullptr;
    }

    if (m_isDownloading) {
        m_isDownloading = false;
        emit isDownloadingChanged();
    }
}

void ScreensaverVideoManager::queueAllVideosForDownload()
{
    m_downloadQueue.clear();

    for (int i = 0; i < m_catalog.size(); ++i) {
        const VideoItem& item = m_catalog[i];

        // Skip if already cached
        if (isVideoCached(item)) {
            continue;
        }

        // Skip if would exceed cache limit
        if (item.bytes > 0 && m_cacheUsedBytes + item.bytes > m_maxCacheBytes) {
            // Try to evict to make room
            evictLruIfNeeded(item.bytes);
            if (m_cacheUsedBytes + item.bytes > m_maxCacheBytes) {
                qDebug() << "[Screensaver] Skipping video" << item.id << "- would exceed cache limit";
                continue;
            }
        }

        m_downloadQueue.append(i);
    }
}

void ScreensaverVideoManager::processDownloadQueue()
{
    if (m_downloadQueue.isEmpty()) {
        qDebug() << "[Screensaver] Download queue complete";
        m_isDownloading = false;
        m_downloadProgress = 1.0;
        emit isDownloadingChanged();
        emit downloadProgressChanged();
        saveCacheIndex();
        return;
    }

    m_currentDownloadIndex = m_downloadQueue.takeFirst();
    const VideoItem& item = m_catalog[m_currentDownloadIndex];

    qDebug() << "[Screensaver] Downloading video" << item.id << ":" << item.author;

    QString url = buildVideoUrl(item);
    QString cachePath = getCachePath(item);

    // Create temp file for download
    m_downloadFile = new QFile(cachePath + ".tmp");
    if (!m_downloadFile->open(QIODevice::WriteOnly)) {
        qWarning() << "[Screensaver] Failed to create download file:" << cachePath;
        delete m_downloadFile;
        m_downloadFile = nullptr;
        // Try next
        QTimer::singleShot(100, this, &ScreensaverVideoManager::processDownloadQueue);
        return;
    }

    m_isDownloading = true;
    emit isDownloadingChanged();

    QNetworkRequest request{QUrl(url)};
    m_downloadReply = m_networkManager->get(request);

    connect(m_downloadReply, &QNetworkReply::downloadProgress,
            this, &ScreensaverVideoManager::onDownloadProgress);
    connect(m_downloadReply, &QNetworkReply::readyRead, this, [this]() {
        if (m_downloadFile && m_downloadReply) {
            m_downloadFile->write(m_downloadReply->readAll());
        }
    });
    connect(m_downloadReply, &QNetworkReply::finished,
            this, &ScreensaverVideoManager::onDownloadFinished);
}

void ScreensaverVideoManager::onDownloadProgress(qint64 received, qint64 total)
{
    if (total > 0) {
        // Calculate overall progress including completed downloads
        int totalVideos = m_catalog.size();
        int completedVideos = 0;
        for (const VideoItem& item : m_catalog) {
            if (isVideoCached(item)) {
                completedVideos++;
            }
        }

        double videoProgress = static_cast<double>(received) / total;
        m_downloadProgress = (completedVideos + videoProgress) / totalVideos;
        emit downloadProgressChanged();
    }
}

void ScreensaverVideoManager::onDownloadFinished()
{
    if (!m_downloadReply || !m_downloadFile) {
        return;
    }

    bool success = (m_downloadReply->error() == QNetworkReply::NoError);
    QString errorString = m_downloadReply->errorString();

    m_downloadFile->close();
    m_downloadReply->deleteLater();
    m_downloadReply = nullptr;

    if (!success) {
        qWarning() << "[Screensaver] Download failed:" << errorString;
        m_downloadFile->remove();
        delete m_downloadFile;
        m_downloadFile = nullptr;
        emit downloadError(errorString);

        // Try next video
        QTimer::singleShot(1000, this, &ScreensaverVideoManager::processDownloadQueue);
        return;
    }

    const VideoItem& item = m_catalog[m_currentDownloadIndex];
    QString cachePath = getCachePath(item);
    QString tempPath = cachePath + ".tmp";

    // Verify SHA256 if available
    if (!item.sha256.isEmpty()) {
        if (!verifySha256(tempPath, item.sha256)) {
            qWarning() << "[Screensaver] SHA256 verification failed, deleting file";
            m_downloadFile->remove();
            delete m_downloadFile;
            m_downloadFile = nullptr;

            // Try next video
            QTimer::singleShot(1000, this, &ScreensaverVideoManager::processDownloadQueue);
            return;
        }
    }

    // Rename temp file to final
    QFile::remove(cachePath);  // Remove any existing file
    if (!QFile::rename(tempPath, cachePath)) {
        qWarning() << "[Screensaver] Failed to rename temp file to:" << cachePath;
        QFile::remove(tempPath);
        delete m_downloadFile;
        m_downloadFile = nullptr;

        QTimer::singleShot(1000, this, &ScreensaverVideoManager::processDownloadQueue);
        return;
    }

    delete m_downloadFile;
    m_downloadFile = nullptr;

    // Update cache index
    CachedVideo cv;
    cv.localPath = cachePath;
    cv.sha256 = item.sha256;
    cv.bytes = QFileInfo(cachePath).size();
    cv.lastAccessed = QDateTime::currentDateTimeUtc();
    cv.catalogId = item.id;

    m_cacheIndex[item.id] = cv;
    m_cacheUsedBytes += cv.bytes;

    qDebug() << "[Screensaver] Downloaded and cached:" << cachePath
             << "(" << (cv.bytes / 1024 / 1024) << "MB)";

    emit cacheUsedBytesChanged();
    emit videoReady(cachePath);

    // Continue with queue
    QTimer::singleShot(100, this, &ScreensaverVideoManager::processDownloadQueue);
}

// Video selection and playback
int ScreensaverVideoManager::selectNextVideoIndex()
{
    if (m_catalog.isEmpty()) {
        return -1;
    }

    // Only play cached videos - no streaming
    QList<int> cachedIndices;

    for (int i = 0; i < m_catalog.size(); ++i) {
        if (i == m_lastPlayedIndex) continue;  // Avoid immediate repeat

        if (isVideoCached(m_catalog[i])) {
            cachedIndices.append(i);
        }
    }

    if (cachedIndices.isEmpty()) {
        // No cached videos yet - return -1 to show fallback
        return -1;
    }

    int randIndex = QRandomGenerator::global()->bounded(cachedIndices.size());
    return cachedIndices[randIndex];
}

QString ScreensaverVideoManager::getNextVideoSource()
{
    int index = selectNextVideoIndex();
    if (index < 0) {
        qDebug() << "[Screensaver] No cached videos available yet";
        return QString();
    }

    const VideoItem& item = m_catalog[index];
    m_lastPlayedIndex = index;

    // Update current video info for credits display
    m_currentVideoAuthor = item.author;
    m_currentVideoSourceUrl = item.sourceUrl.isEmpty() ? item.authorUrl : item.sourceUrl;
    emit currentVideoChanged();

    // Return cached video path
    QString localPath = m_cacheIndex[item.id].localPath;
    qDebug() << "[Screensaver] Playing cached video:" << localPath;
    return QUrl::fromLocalFile(localPath).toString();
}

void ScreensaverVideoManager::markVideoPlayed(const QString& source)
{
    // Update last accessed time for LRU tracking
    for (auto it = m_cacheIndex.begin(); it != m_cacheIndex.end(); ++it) {
        if (source.contains(it.value().localPath) ||
            QUrl::fromLocalFile(it.value().localPath).toString() == source) {
            it.value().lastAccessed = QDateTime::currentDateTimeUtc();
            saveCacheIndex();
            break;
        }
    }
}

QVariantList ScreensaverVideoManager::creditsList() const
{
    QVariantList credits;

    for (const VideoItem& item : m_catalog) {
        QVariantMap credit;
        credit["author"] = item.author;
        credit["authorUrl"] = item.authorUrl;
        credit["sourceUrl"] = item.sourceUrl;
        credit["duration"] = item.durationSeconds;
        credits.append(credit);
    }

    return credits;
}
