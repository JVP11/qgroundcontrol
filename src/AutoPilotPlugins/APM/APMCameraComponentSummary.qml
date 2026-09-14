import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

Item {
    anchors.fill:   parent

    FactPanelController { id: controller; }

    property Fact _mountRCInTilt:   controller.getParameterFact(-1, "MNT_RC_IN_TILT", false)
    property Fact _mountRCInRoll:   controller.getParameterFact(-1, "MNT_RC_IN_ROLL", false)
    property Fact _mountRCInPan:    controller.getParameterFact(-1, "MNT_RC_IN_PAN", false)

    // MNT_TYPE parameter is not in older firmware versions
    property bool   _mountTypeExists: controller.parameterExists(-1, "MNT_TYPE")
    property Fact   _mountType: controller.getParameterFact(-1, "MNT_TYPE", false)
    property string _mountTypeValue: (_mountTypeExists && _mountType) ? _mountType.enumStringValue : ""

    // Check if mount parameters exist
    property bool _mountRCInTiltExists: controller.parameterExists(-1, "MNT_RC_IN_TILT")
    property bool _mountRCInRollExists: controller.parameterExists(-1, "MNT_RC_IN_ROLL")
    property bool _mountRCInPanExists: controller.parameterExists(-1, "MNT_RC_IN_PAN")

    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
            visible:    _mountTypeExists
            labelText:  qsTr("Gimbal type")
            valueText:  _mountTypeValue
        }

        VehicleSummaryRow {
            visible:    _mountRCInTiltExists
            labelText:  qsTr("Tilt input channel")
            valueText:  _mountRCInTilt ? _mountRCInTilt.enumStringValue : ""
        }

        VehicleSummaryRow {
            visible:    _mountRCInPanExists
            labelText:  qsTr("Pan input channel")
            valueText:  _mountRCInPan ? _mountRCInPan.enumStringValue : ""
        }

        VehicleSummaryRow {
            visible:    _mountRCInRollExists
            labelText:  qsTr("Roll input channel")
            valueText:  _mountRCInRoll ? _mountRCInRoll.enumStringValue : ""
        }
    }
}
