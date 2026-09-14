/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


/// @file
///     @author Don Gagne <don@thegagnes.com>

#include "QGCPalette.h"
#include "QGCCorePlugin.h"

#include <QtCore/QDebug>

QList<QGCPalette*>   QGCPalette::_paletteObjects;

QGCPalette::Theme QGCPalette::_theme = QGCPalette::Dark;

QMap<int, QMap<int, QMap<QString, QColor>>> QGCPalette::_colorInfoMap;

QStringList QGCPalette::_colors;

QGCPalette::QGCPalette(QObject* parent) :
    QObject(parent),
    _colorGroupEnabled(true)
{
    if (_colorInfoMap.isEmpty()) {
        _buildMap();
    }

    // We have to keep track of all QGCPalette objects in the system so we can signal theme change to all of them
    _paletteObjects += this;
}

QGCPalette::~QGCPalette()
{
    bool fSuccess = _paletteObjects.removeOne(this);
    if (!fSuccess) {
        qWarning() << "Internal error";
    }
}

void QGCPalette::_buildMap()
{
    // ============================================================================
    // ASTHRA MILITARY-INDUSTRIAL COLOR PALETTE
    // Tactical ground control system - Enhanced military/industrial aesthetic
    // Darker, more muted, higher contrast, utilitarian design
    // ============================================================================
    //
    //                                      Light                 Dark
    //                                      Disabled   Enabled    Disabled   Enabled

    // === PRIMARY BACKGROUND COLORS ===
    // Main window: Tactical Black #050708 (darker, more matte)
    // Panel background: Battlefield Grey #0F1215 (darker charcoal)
    // Raised panels: Industrial Slate #181C20 (darker raised)
    // Borders / dividers: Tactical Steel #1F2327 (sharper contrast)
    DECLARE_QGC_COLOR(window,               "#050708", "#050708", "#050708", "#050708")  // Tactical Black
    DECLARE_QGC_COLOR(windowTransparent,    "#e6050708", "#e6050708", "#e6050708", "#e6050708")
    DECLARE_QGC_COLOR(windowShadeLight,     "#1F2327", "#1F2327", "#1F2327", "#1F2327")  // Tactical Steel
    DECLARE_QGC_COLOR(windowShade,          "#0F1215", "#0F1215", "#0F1215", "#0F1215")  // Battlefield Grey
    DECLARE_QGC_COLOR(windowShadeDark,      "#181C20", "#181C20", "#181C20", "#181C20")  // Industrial Slate

    // === TEXT COLORS ===
    // Primary text: Tactical White #F0F2F4 (higher contrast)
    // Secondary text: Field Grey #8B9199 (more muted)
    // Disabled text: Dormant Grey #4A4F56 (darker, more industrial)
    // Labels / headers: Command White #D8DCE0 (sharp, readable)
    DECLARE_QGC_COLOR(text,                 "#4A4F56", "#8B9199", "#4A4F56", "#F0F2F4")  // Primary: Tactical White
    DECLARE_QGC_COLOR(windowTransparentText,"#4A4F56", "#8B9199", "#4A4F56", "#F0F2F4")
    DECLARE_QGC_COLOR(warningText,          "#D4A017", "#D4A017", "#D4A017", "#D4A017")  // Tactical Amber

    // === BUTTON COLORS (MILITARY HMI STYLE) ===
    // Primary action: #1F2327 background, #F0F2F4 text (sharper contrast)
    // Hover: #2A2E33 background, #FFFFFF text
    // Active / pressed: #14171A background, #FFFFFF text
    // Critical action: #4A1A1A background, #FFFFFF text (darker red)
    DECLARE_QGC_COLOR(button,               "#1F2327", "#1F2327", "#1F2327", "#1F2327")  // Tactical Steel
    DECLARE_QGC_COLOR(buttonBorder,         "#2A3036", "#2A3036", "#2A3036", "#2A3036")  // Industrial Border
    DECLARE_QGC_COLOR(buttonText,           "#4A4F56", "#8B9199", "#4A4F56", "#F0F2F4")  // Tactical White
    DECLARE_QGC_COLOR(buttonHighlight,      "#2A2E33", "#2A2E33", "#2A2E33", "#2A2E33")  // Hover
    DECLARE_QGC_COLOR(buttonHighlightText,  "#FFFFFF", "#FFFFFF", "#FFFFFF", "#FFFFFF")  // White on hover

    // === PRIMARY BUTTON ===
    DECLARE_QGC_COLOR(primaryButton,        "#1F2327", "#1F2327", "#1F2327", "#1F2327")  // Tactical Steel
    DECLARE_QGC_COLOR(primaryButtonText,   "#F0F2F4", "#F0F2F4", "#F0F2F4", "#F0F2F4")  // Tactical White

    // === TEXT FIELD COLORS ===
    DECLARE_QGC_COLOR(textField,            "#0F1215", "#0F1215", "#0F1215", "#0F1215")  // Battlefield Grey
    DECLARE_QGC_COLOR(textFieldText,        "#4A4F56", "#F0F2F4", "#4A4F56", "#F0F2F4")  // Tactical White

    // === MAP BUTTON COLORS ===
    DECLARE_QGC_COLOR(mapButton,            "#181C20", "#181C20", "#181C20", "#181C20")  // Industrial Slate
    DECLARE_QGC_COLOR(mapButtonHighlight,   "#2A3D4A", "#2A3D4A", "#2A3D4A", "#2A3D4A")  // Tactical Blue-Grey
    DECLARE_QGC_COLOR(mapIndicator,         "#2A3D4A", "#2A3D4A", "#2A3D4A", "#2A3D4A")  // Tactical Blue-Grey
    DECLARE_QGC_COLOR(mapIndicatorChild,     "#181C20", "#181C20", "#181C20", "#181C20")  // Industrial Slate

    // === STATUS & SYSTEM COLORS (ENHANCED MILITARY STANDARD) ===
    // Normal / OK: Tactical Green #1F6B3F (darker, more muted)
    // Active / Armed: Command Green #2A8B55 (sharper, operational)
    // Warning: Tactical Amber #D4A017 (more muted, industrial)
    // Critical / Error: Alert Red #9B2D2D (deeper, more serious)
    // Link lost / inactive: Signal Grey #3D4247 (darker, more industrial)
    DECLARE_QGC_COLOR(colorGreen,           "#1F6B3F", "#2A8B55", "#1F6B3F", "#2A8B55")  // Tactical/Command Green
    DECLARE_QGC_COLOR(colorYellow,          "#D4A017", "#D4A017", "#D4A017", "#D4A017")  // Tactical Amber
    DECLARE_QGC_COLOR(colorYellowGreen,     "#2A8B55", "#2A8B55", "#2A8B55", "#2A8B55")  // Command Green
    DECLARE_QGC_COLOR(colorOrange,          "#D4A017", "#D4A017", "#D4A017", "#D4A017")  // Tactical Amber (warning)
    DECLARE_QGC_COLOR(colorRed,             "#9B2D2D", "#9B2D2D", "#9B2D2D", "#9B2D2D")  // Alert Red (deeper)
    DECLARE_QGC_COLOR(colorGrey,            "#3D4247", "#3D4247", "#3D4247", "#3D4247")  // Signal Grey (darker)
    DECLARE_QGC_COLOR(colorBlue,            "#2D4A5F", "#2D4A5F", "#2D4A5F", "#2D4A5F")  // Tactical Blue (muted)

    // === ALERT COLORS ===
    DECLARE_QGC_COLOR(alertBackground,      "#D4A017", "#D4A017", "#D4A017", "#D4A017")  // Tactical Amber
    DECLARE_QGC_COLOR(alertBorder,          "#1F2327", "#1F2327", "#1F2327", "#1F2327")  // Tactical Steel
    DECLARE_QGC_COLOR(alertText,            "#050708", "#050708", "#050708", "#050708")  // Tactical Black

    // === MISSION EDITOR COLORS ===
    DECLARE_QGC_COLOR(missionItemEditor,    "#0F1215", "#181C20", "#0F1215", "#181C20")  // Battlefield Grey / Industrial Slate
    DECLARE_QGC_COLOR(toolStripHoverColor,  "#2A2E33", "#2A2E33", "#2A2E33", "#2A2E33")  // Hover

    // === STATUS TEXT COLORS ===
    DECLARE_QGC_COLOR(statusFailedText,     "#9B2D2D", "#9B2D2D", "#9B2D2D", "#9B2D2D")  // Alert Red
    DECLARE_QGC_COLOR(statusPassedText,     "#2A8B55", "#2A8B55", "#2A8B55", "#2A8B55")  // Command Green
    DECLARE_QGC_COLOR(statusPendingText,    "#D4A017", "#D4A017", "#D4A017", "#D4A017")  // Tactical Amber

    // === TOOLBAR BACKGROUND ===
    DECLARE_QGC_COLOR(toolbarBackground,    "#00050708", "#00050708", "#00050708", "#00050708")  // Transparent Tactical Black

    // === GROUP BORDER ===
    DECLARE_QGC_COLOR(groupBorder,          "#1F2327", "#1F2327", "#1F2327", "#1F2327")  // Tactical Steel

    // ============================================================================
    // NON-THEMED COLORS (consistent across light/dark)
    // ============================================================================

    // === BRANDING ===
    //                                                      Disabled     Enabled
    DECLARE_QGC_NONTHEMED_COLOR(brandingPurple,             "#050708", "#050708")      // Tactical Black
    DECLARE_QGC_NONTHEMED_COLOR(brandingBlue,               "#2D4A5F", "#2D4A5F")      // Tactical Blue
    DECLARE_QGC_NONTHEMED_COLOR(toolStripFGColor,           "#4A4F56", "#F0F2F4")      // Tactical White
    DECLARE_QGC_NONTHEMED_COLOR(photoCaptureButtonColor,    "#8B9199", "#F0F2F4")      // Tactical White
    DECLARE_QGC_NONTHEMED_COLOR(videoCaptureButtonColor,    "#9B2D2D", "#9B2D2D")      // Alert Red

    // ============================================================================
    // SINGLE COLORS (same everywhere)
    // ============================================================================
    DECLARE_QGC_SINGLE_COLOR(mapWidgetBorderLight,          "#1F2327")  // Tactical Steel
    DECLARE_QGC_SINGLE_COLOR(mapWidgetBorderDark,           "#050708")  // Tactical Black
    DECLARE_QGC_SINGLE_COLOR(mapMissionTrajectory,          "#3A7A8A")  // Tactical Cyan (muted)
    DECLARE_QGC_SINGLE_COLOR(surveyPolygonInterior,         "#2A8B55")  // Command Green
    DECLARE_QGC_SINGLE_COLOR(surveyPolygonTerrainCollision, "#7A2525")  // Restricted Red (darker)

// Colors for UTM Adapter
#ifdef QGC_UTM_ADAPTER
    DECLARE_QGC_COLOR(switchUTMSP,        "#b0e0e6", "#b0e0e6", "#b0e0e6", "#b0e0e6");
    DECLARE_QGC_COLOR(sliderUTMSP,        "#9370db", "#9370db", "#9370db", "#9370db");
    DECLARE_QGC_COLOR(successNotifyUTMSP, "#3cb371", "#3cb371", "#3cb371", "#3cb371");
#endif
}

void QGCPalette::setColorGroupEnabled(bool enabled)
{
    _colorGroupEnabled = enabled;
    emit paletteChanged();
}

void QGCPalette::setGlobalTheme(Theme newTheme)
{
    // Mobile build does not have themes
    if (_theme != newTheme) {
        _theme = newTheme;
        _signalPaletteChangeToAll();
    }
}

void QGCPalette::_signalPaletteChangeToAll()
{
    // Notify all objects of the new theme
    for (QGCPalette *palette : std::as_const(_paletteObjects)) {
        palette->_signalPaletteChanged();
    }
}

void QGCPalette::_signalPaletteChanged()
{
    emit paletteChanged();
}
