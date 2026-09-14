/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


#include "QGCFileDialogController.h"
#include "QGCLoggingCategory.h"
#include "SettingsManager.h"
#include "AppSettings.h"

#include <QtCore/QDir>

QGC_LOGGING_CATEGORY(QGCFileDialogControllerLog, "QMLControls.QGCFileDialogController")

QGCFileDialogController::QGCFileDialogController(QObject *parent)
    : QObject(parent)
{
    qCDebug(QGCFileDialogControllerLog) << this;
}

QGCFileDialogController::~QGCFileDialogController()
{
    qCDebug(QGCFileDialogControllerLog) << this;
}

QStringList QGCFileDialogController::getFiles(const QString &directoryPath, const QStringList &nameFilters)
{
    qCDebug(QGCFileDialogControllerLog) << "getFiles" << directoryPath << nameFilters;

    QDir fileDir(directoryPath);
    const QFileInfoList fileInfoList = fileDir.entryInfoList(nameFilters,  QDir::Files, QDir::Name);

    QStringList files;
    for (const QFileInfo &fileInfo: fileInfoList) {
        qCDebug(QGCFileDialogControllerLog) << "getFiles found" << fileInfo.fileName();
        files << fileInfo.fileName();
    }

    return files;
}

bool QGCFileDialogController::fileExists(const QString &filename)
{
    return QFile(filename).exists();
}

QString QGCFileDialogController::fullyQualifiedFilename(const QString& directoryPath, const QString& filename, const QStringList& nameFilters)
{
    QString firstFileExtention;

    // Check that the filename has one of the specified file extensions

    bool extensionFound = true;
    if (nameFilters.count()) {
        extensionFound = false;
        for (const QString& nameFilter: nameFilters) {
            if (nameFilter.startsWith("*.")) {
                const QString fileExtension = nameFilter.right(nameFilter.length() - 2);
                if (fileExtension != "*") {
                    if (firstFileExtention.isEmpty()) {
                        firstFileExtention = fileExtension;
                    }
                    if (filename.endsWith(fileExtension)) {
                        extensionFound = true;
                        break;
                    }
                }
            } else if (nameFilter != "*") {
                qCWarning(QGCFileDialogControllerLog) << "unsupported name filter format" << nameFilter;
            }
        }
    }

    // Add the extension if it is missing
    QString filenameWithExtension = filename;
    if (!extensionFound) {
        filenameWithExtension = QStringLiteral("%1.%2").arg(filename).arg(firstFileExtention);
    }

    return (directoryPath + QStringLiteral("/") + filenameWithExtension);
}

void QGCFileDialogController::deleteFile(const QString &filename)
{
    QFile::remove(filename);
}

QString QGCFileDialogController::fullFolderPathToShortMobilePath(const QString &fullFolderPath)
{
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    const QString defaultSavePath = SettingsManager::instance()->appSettings()->savePath()->rawValueString();
    if (fullFolderPath.startsWith(defaultSavePath)) {
        const int lastDirSepIndex = fullFolderPath.lastIndexOf(QStringLiteral("/"));
        return (QCoreApplication::applicationName() + QStringLiteral("/") + fullFolderPath.right(fullFolderPath.length() - lastDirSepIndex));
    }
#else
    qCWarning(QGCFileDialogControllerLog) << Q_FUNC_INFO << "should only be used in mobile builds";
#endif
    return fullFolderPath;
}

QString QGCFileDialogController::urlToLocalFile(QUrl url)
{
    // For some strange reason on Qt6 running on Linux files returned by FileDialog are not returned as local file urls.
    // Seems to be new behavior with Qt6.
    if (url.isLocalFile()) {
        return url.toLocalFile();
    }

    return url.toString();
}

bool QGCFileDialogController::writeTextFile(const QString &filePath, const QString &content)
{
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qCWarning(QGCFileDialogControllerLog) << "Failed to open file for writing:" << filePath << file.errorString();
        return false;
    }

    QTextStream out(&file);
    out << content;
    file.close();

    qCDebug(QGCFileDialogControllerLog) << "Successfully wrote" << content.length() << "characters to" << filePath;
    return true;
}

QString QGCFileDialogController::saveFileDialog(const QString &title, const QString &defaultName, const QString &nameFilters)
{
    // This is a placeholder - actual file dialog should be shown from QML
    // QML FileDialog should be used, this just returns the path format
    qCDebug(QGCFileDialogControllerLog) << "saveFileDialog called - use QML FileDialog instead";
    return QString();
}
