/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "ShapeFileHelper.h"
#include "KMLHelper.h"
#include "SHPFileHelper.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QVariant>
#include <QtCore/QFile>
#include <QtCore/QDir>
#include <QtCore/QStandardPaths>

QGC_LOGGING_CATEGORY(ShapeFileHelperLog, "Utilities.ShapeFileHelper")

bool ShapeFileHelper::_fileIsKML(const QString &file, QString &errorString)
{
    return (_getShapeFileType(file, errorString) == ShapeFileType::KML);
}

bool ShapeFileHelper::_fileIsSHP(const QString &file, QString &errorString)
{
    return (_getShapeFileType(file, errorString) == ShapeFileType::SHP);
}

ShapeFileHelper::ShapeFileType ShapeFileHelper::_getShapeFileType(const QString &file, QString &errorString)
{
    errorString.clear();

    if (file.endsWith(kmlFileExtension)) {
        return ShapeFileType::KML;
    } else if (file.endsWith(shpFileExtension)) {
        return ShapeFileType::SHP;
    } else {
        errorString = QString(_errorPrefix).arg(tr("Unsupported file type. Only .%1 and .%2 are supported.").arg(kmlFileExtension, shpFileExtension));
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

bool ShapeFileHelper::loadPolygonFromFile(const QString &file, QList<QGeoCoordinate> &vertices, QString &errorString)
{
    errorString.clear();
    vertices.clear();

    switch (_getShapeFileType(file, errorString)) {
    case ShapeFileType::KML:
        return KMLHelper::loadPolygonFromFile(file, vertices, errorString);
    case ShapeFileType::SHP:
        return SHPFileHelper::loadPolygonFromFile(file, vertices, errorString);
    case ShapeFileType::None:
    default:
        return false;
    }
}

bool ShapeFileHelper::loadPolylineFromFile(const QString &file, QList<QGeoCoordinate> &coords, QString &errorString)
{
    errorString.clear();
    coords.clear();

    switch (_getShapeFileType(file, errorString)) {
    case ShapeFileType::KML:
        return KMLHelper::loadPolylineFromFile(file, coords, errorString);
    case ShapeFileType::SHP:
        return SHPFileHelper::loadPolylineFromFile(file, coords, errorString);
    case ShapeFileType::None:
    default:
        return false;
    }
}

QVariantMap ShapeFileHelper::loadPolygonQml(const QString &file)
{
    QVariantMap result;
    QList<QGeoCoordinate> vertices;
    QString errorString;
    const bool ok = loadPolygonFromFile(file, vertices, errorString);
    QVariantList path;
    path.reserve(vertices.size());
    for (const QGeoCoordinate &coord : vertices) {
        path.append(QVariant::fromValue(coord));
    }
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
    static const QStringList filters = QStringList(tr("KML Files (*.%1)").arg(kmlFileExtension));
    return filters;
}

QStringList ShapeFileHelper::fileDialogKMLOrSHPFilters()
{
    static const QStringList filters = QStringList(tr("KML/SHP Files (*.%1 *.%2)").arg(kmlFileExtension, shpFileExtension));
    return filters;
}
