#include "ShapeFileHelper.h"
#include "KMLHelper.h"
#include "SHPFileHelper.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QStandardPaths>
#include <QtCore/QVariant>

QGC_LOGGING_CATEGORY(ShapeFileHelperLog, "Utilities.ShapeFileHelper")

namespace {
    constexpr const char *_errorPrefix = QT_TRANSLATE_NOOP("ShapeFileHelper", "Shape file load failed. %1");
}

ShapeFileHelper::ShapeFileType ShapeFileHelper::_getShapeFileType(const QString &file, QString &errorString)
{
    errorString.clear();

    if (file.endsWith(kmlFileExtension, Qt::CaseInsensitive)) {
        return ShapeFileType::KML;
    } else if (file.endsWith(shpFileExtension, Qt::CaseInsensitive)) {
        return ShapeFileType::SHP;
    } else {
        // Strip leading dots for user-friendly error message
        const QString kmlExt = QString(kmlFileExtension).mid(1);
        const QString shpExt = QString(shpFileExtension).mid(1);
        errorString = tr(_errorPrefix).arg(tr("Unsupported file type. Only %1 and %2 are supported.").arg(kmlExt, shpExt));
    }

    return ShapeFileType::None;
}

ShapeFileHelper::ShapeType ShapeFileHelper::determineShapeType(const QString &file, QString &errorString)
{
    errorString.clear();

    switch (_getShapeFileType(file, errorString)) {
    case ShapeFileType::KML:
        return KMLHelper::determineShapeType(file, errorString);
    case ShapeFileType::SHP:
        return SHPFileHelper::determineShapeType(file, errorString);
    case ShapeFileType::None:
    default:
        return ShapeType::Error;
    }
}

int ShapeFileHelper::getEntityCount(const QString &file, QString &errorString)
{
    errorString.clear();

    switch (_getShapeFileType(file, errorString)) {
    case ShapeFileType::KML:
        return KMLHelper::getEntityCount(file, errorString);
    case ShapeFileType::SHP:
        return SHPFileHelper::getEntityCount(file, errorString);
    case ShapeFileType::None:
    default:
        return 0;
    }
}

bool ShapeFileHelper::loadPolygonsFromFile(const QString &file, QList<QList<QGeoCoordinate>> &polygons, QString &errorString, double filterMeters)
{
    errorString.clear();
    polygons.clear();

    switch (_getShapeFileType(file, errorString)) {
    case ShapeFileType::KML:
        return KMLHelper::loadPolygonsFromFile(file, polygons, errorString, filterMeters);
    case ShapeFileType::SHP:
        return SHPFileHelper::loadPolygonsFromFile(file, polygons, errorString, filterMeters);
    case ShapeFileType::None:
    default:
        return false;
    }
}

bool ShapeFileHelper::loadPolylinesFromFile(const QString &file, QList<QList<QGeoCoordinate>> &polylines, QString &errorString, double filterMeters)
{
    errorString.clear();
    polylines.clear();

    switch (_getShapeFileType(file, errorString)) {
    case ShapeFileType::KML:
        return KMLHelper::loadPolylinesFromFile(file, polylines, errorString, filterMeters);
    case ShapeFileType::SHP:
        return SHPFileHelper::loadPolylinesFromFile(file, polylines, errorString, filterMeters);
    case ShapeFileType::None:
    default:
        return false;
    }
}

bool ShapeFileHelper::loadPointsFromFile(const QString &file, QList<QGeoCoordinate> &points, QString &errorString)
{
    errorString.clear();
    points.clear();

    switch (_getShapeFileType(file, errorString)) {
    case ShapeFileType::KML:
        return KMLHelper::loadPointsFromFile(file, points, errorString);
    case ShapeFileType::SHP:
        return SHPFileHelper::loadPointsFromFile(file, points, errorString);
    case ShapeFileType::None:
    default:
        return false;
    }
}

QVariantMap ShapeFileHelper::loadPolygonQml(const QString &file)
{
    QList<QList<QGeoCoordinate>> polygons;
    QString errorString;
    bool ok = loadPolygonsFromFile(file, polygons, errorString);
    QVariantList path;
    if (ok && !polygons.isEmpty()) {
        const QList<QGeoCoordinate> &vertices = polygons.first();
        path.reserve(vertices.size());
        for (const QGeoCoordinate &coord : vertices) {
            path.append(QVariant::fromValue(coord));
        }
    } else if (ok) {
        ok = false;
        errorString = tr("No polygon found in file.");
    }

    QVariantMap result;
    result.insert(QStringLiteral("ok"), ok);
    result.insert(QStringLiteral("error"), errorString);
    result.insert(QStringLiteral("path"), path);
    return result;
}

QString ShapeFileHelper::writeTempText(const QString &fileName, const QString &text)
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    if (dir.isEmpty() || fileName.isEmpty()) {
        return {};
    }
    QDir().mkpath(dir);
    const QString path = dir + QLatin1Char('/') + fileName;
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        return {};
    }
    file.write(text.toUtf8());
    file.close();
    return path;
}

QStringList ShapeFileHelper::fileDialogKMLFilters()
{
    static const QStringList filters = QStringList(tr("KML Files (*%1)").arg(kmlFileExtension));
    return filters;
}

QStringList ShapeFileHelper::fileDialogKMLOrSHPFilters()
{
    static const QStringList filters = QStringList(tr("KML/SHP Files (*%1 *%2)").arg(kmlFileExtension, shpFileExtension));
    return filters;
}
