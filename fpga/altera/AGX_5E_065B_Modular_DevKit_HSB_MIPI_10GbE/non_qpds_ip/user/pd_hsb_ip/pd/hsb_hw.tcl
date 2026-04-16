###################################################################################
# Copyright (C) 2025 Altera Corporation
#
# This software and the related documents are Altera copyrighted materials, and
# your use of them is governed by the express license under which they were
# provided to you ("License"). Unless the License provides otherwise, you may
# not use, modify, copy, publish, distribute, disclose or transmit this software
# or the related documents without Altera's prior written permission.
#
# This software and the related documents are provided as is, with no express
# or implied warranties, other than those that are expressly stated in the License.
###################################################################################

package require -exact qsys 24.3.1
package require altera_terp

set_module_property DESCRIPTION                  "NVIDIA Holoscan Sensor Bridge IP"
set_module_property NAME                         nvidia_hsb
set_module_property VERSION                      26.03
set_module_property INTERNAL                     false
set_module_property OPAQUE_ADDRESS_MAP           false
set_module_property GROUP                        "External IP"
set_module_property DISPLAY_NAME                 "NVIDIA Holoscan Sensor Bridge IP"
set_module_property AUTHOR                       "NVIDIA Corporation"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property ELABORATION_CALLBACK         elab_callback
set_module_property VALIDATION_CALLBACK          val_callback

################################################################################
# Create the User interface
################################################################################
proc create_ui { } {

  add_display_item "" "General"     group tab
  add_display_item "" "Dataplane"   group tab
  add_display_item "" "Peripherals" group tab

  add_display_item "General"                        "ID"                            group
  add_display_item "ID"                             BUILD_REV                       parameter
  add_display_item "ID"                             UUID                            parameter
  add_display_item "ID"                             BOARD_ID                        parameter
  add_display_item "General"                        "Enumeration"                   group
  add_display_item "Enumeration"                    ENUM_EEPROM                     parameter
  add_display_item "Enumeration"                    EEPROM_REG_ADDR_BITS            parameter
  add_display_item "Enumeration"                    EXPOSE_ID                       parameter
  add_display_item "Enumeration"                    EXPOSE_ID_SINGLE_INTF           parameter
  add_display_item "Enumeration"                    BOARD_SN                        parameter
  add_display_item "General"                        "Initialization Registers"      group
  add_display_item "Initialization Registers"       INIT_REG_FILE                   parameter
  add_display_item "Initialization Registers"       INIT_REG_FILE_FORMAT            parameter
  add_display_item "General"                        "Sensor Event Interrupts"       group
  add_display_item "Sensor Event Interrupts"        NUM_SIF_EVENT                   parameter
  add_display_item "Sensor Event Interrupts"        IND_SIF_EVENT                   parameter
  add_display_item "General"                        "Software Sensor Resets"        group
  add_display_item "Software Sensor Resets"         NUM_SW_SEN_RST                  parameter
  add_display_item "Software Sensor Resets"         IND_SW_SEN_RST                  parameter

  add_display_item "Dataplane"                      "Host"                          group
  add_display_item "Host"                           HOST_IF_INST                    parameter
  add_display_item "Host"                           HIF_CLK_FREQ                    parameter
  add_display_item "Host"                           HOST_MTU                        parameter
  add_display_item "Host"                           HOST_WIDTH                      parameter
  add_display_item "Host"                           HOSTKEEP_WIDTH                  parameter
  add_display_item "Host"                           HOSTUSER_WIDTH                  parameter
  add_display_item "Dataplane"                      "Sensor"                        group
  add_display_item "Sensor"                         DATAPATH_WIDTH                  parameter
  add_display_item "Sensor"                         DATAKEEP_WIDTH                  parameter
  add_display_item "Sensor"                         DATAUSER_WIDTH                  parameter
  add_display_item "Sensor"                         "Sensor RX"                     group
  add_display_item "Sensor"                         "Sensor TX"                     group

  add_display_item "Peripherals"                    "Peripheral Interface"          group
  add_display_item "Peripheral Interface"           UART_INST                       parameter
  add_display_item "Peripheral Interface"           SPI_INST                        parameter
  add_display_item "Peripheral Interface"           I2C_INST                        parameter
  add_display_item "Peripheral Interface"           GPIO_INST                       parameter
  add_display_item "Peripheral Interface"           GPIO_RESET_VALUE                parameter
  add_display_item "Peripherals"                    "Register Interface"            group
  add_display_item "Register Interface"             REG_INST                        parameter
  add_display_item "Register Interface"             SYNC_CLK_HIF_APB                parameter
  add_display_item "Register Interface"             APB_CLK_FREQ                    parameter
  add_display_item "Register Interface"             APB_CLK_FREQ_GUI                parameter
  add_display_item "Peripherals"                    "Precision Time Protocol (PTP)" group
  add_display_item "Precision Time Protocol (PTP)"  SYNC_CLK_HIF_PTP                parameter
  add_display_item "Precision Time Protocol (PTP)"  PTP_CLK_FREQ                    parameter
  add_display_item "Precision Time Protocol (PTP)"  PTP_CLK_FREQ_GUI                parameter
  add_display_item "Precision Time Protocol (PTP)"  EXT_PTP                         parameter

  add_parameter           BUILD_REV             STD_LOGIC_VECTOR      0
  set_parameter_property  BUILD_REV             DISPLAY_NAME          "Build Revision"
  set_parameter_property  BUILD_REV             DISPLAY_UNITS         "48-bit"
  set_parameter_property  BUILD_REV             WIDTH                 48
  set_parameter_property  BUILD_REV             ALLOWED_RANGES        0:[expr {(1<<48)-1}]
  set_parameter_property  BUILD_REV             AFFECTS_ELABORATION   false

  add_parameter           UUID                  STD_LOGIC_VECTOR      0
  set_parameter_property  UUID                  DISPLAY_NAME          "UUID"
  set_parameter_property  UUID                  DISPLAY_UNITS         "128-bit"
  set_parameter_property  UUID                  WIDTH                 128
  set_parameter_property  UUID                  ALLOWED_RANGES        0:[expr {(1<<128)-1}]
  set_parameter_property  UUID                  AFFECTS_ELABORATION   false

  add_parameter           BOARD_ID              STD_LOGIC_VECTOR      0
  set_parameter_property  BOARD_ID              DISPLAY_NAME          "Board ID"
  set_parameter_property  BOARD_ID              DISPLAY_UNITS         "8-bit"
  set_parameter_property  BOARD_ID              WIDTH                 8
  set_parameter_property  BOARD_ID              ALLOWED_RANGES        0:255
  set_parameter_property  BOARD_ID              AFFECTS_ELABORATION   false

  add_parameter           BOARD_SN              STD_LOGIC_VECTOR      0
  set_parameter_property  BOARD_SN              DISPLAY_NAME          "Board Serial Number"
  set_parameter_property  BOARD_SN              DISPLAY_UNITS         "56-bit"
  set_parameter_property  BOARD_SN              WIDTH                 56
  set_parameter_property  BOARD_SN              ALLOWED_RANGES        0:[expr {(1<<56)-1}]
  set_parameter_property  BOARD_SN              AFFECTS_ELABORATION   false

  add_parameter           I2C_INST              INTEGER               1
  set_parameter_property  I2C_INST              DISPLAY_NAME          "I2C Interfaces"
  set_parameter_property  I2C_INST              ALLOWED_RANGES        0:8
  set_parameter_property  I2C_INST              AFFECTS_ELABORATION   true

  add_parameter           SPI_INST              INTEGER               1
  set_parameter_property  SPI_INST              DISPLAY_NAME          "SPI Interfaces"
  set_parameter_property  SPI_INST              ALLOWED_RANGES        0:8
  set_parameter_property  SPI_INST              AFFECTS_ELABORATION   true

  add_parameter           UART_INST             INTEGER               0
  set_parameter_property  UART_INST             DISPLAY_NAME          "Enable UART"
  set_parameter_property  UART_INST             DISPLAY_HINT          boolean
  set_parameter_property  UART_INST             AFFECTS_ELABORATION   true

  add_parameter           REG_INST              INTEGER               1
  set_parameter_property  REG_INST              DISPLAY_NAME          "Register Interfaces"
  set_parameter_property  REG_INST              ALLOWED_RANGES        1:8
  set_parameter_property  REG_INST              AFFECTS_ELABORATION   true

  add_parameter           GPIO_INST             INTEGER               16
  set_parameter_property  GPIO_INST             DISPLAY_NAME          "GPIO Interface Width"
  set_parameter_property  GPIO_INST             AFFECTS_ELABORATION   true
  set_parameter_property  GPIO_INST             ALLOWED_RANGES        0:255

  add_parameter           GPIO_RESET_VALUE      STRING                "0b0000_0000_0000_0000"
  set_parameter_property  GPIO_RESET_VALUE      DISPLAY_NAME          "GPIO Reset Value"
  set_parameter_property  GPIO_RESET_VALUE      DESCRIPTION           "Value may be binary (0b prefix) or hexadecimal (0x prefix). Digits may be separated by single underscores."
  set_parameter_property  GPIO_RESET_VALUE      AFFECTS_ELABORATION   false

  add_parameter           INIT_REG_FILE         STRING                {}
  set_parameter_property  INIT_REG_FILE         DISPLAY_NAME          "Initialization Register File"
  set_parameter_property  INIT_REG_FILE         DISPLAY_HINT          {file}
  set_parameter_property  INIT_REG_FILE         AFFECTS_ELABORATION   false

  add_parameter           INIT_REG_FILE_FORMAT  STRING                {Text}
  set_parameter_property  INIT_REG_FILE_FORMAT  DISPLAY_NAME          "Initialization Register File Format"
  set_parameter_property  INIT_REG_FILE_FORMAT  DESCRIPTION           "Text: Pairs of 32-bit hex values for address and data separated by a comma or whitespace. The hex prefix 0x is optional. Digits may be separated by single underscores. Single line comments with // or # are allowed and ignored.<br>Intel HEX: Supports Data, Extended Linear Address, and EOF type fields."
  set_parameter_property  INIT_REG_FILE_FORMAT  DISPLAY_HINT          {file}
  set_parameter_property  INIT_REG_FILE_FORMAT  ALLOWED_RANGES        {Text {Intel HEX}}
  set_parameter_property  INIT_REG_FILE_FORMAT  AFFECTS_ELABORATION   false

  # Data Width

  add_parameter           DATAPATH_WIDTH    INTEGER                   8
  set_parameter_property  DATAPATH_WIDTH    DISPLAY_NAME              "Datapath Width"
  set_parameter_property  DATAPATH_WIDTH    AFFECTS_ELABORATION       false
  set_parameter_property  DATAPATH_WIDTH    ALLOWED_RANGES            {8 16 32 64 128 256 512 1024}

  add_parameter           DATAKEEP_WIDTH    INTEGER                   1
  set_parameter_property  DATAKEEP_WIDTH    DISPLAY_NAME              "Datakeep Width"
  set_parameter_property  DATAKEEP_WIDTH    DESCRIPTION               "Datapath Width divided by 8"
  set_parameter_property  DATAKEEP_WIDTH    AFFECTS_ELABORATION       false
  set_parameter_property  DATAKEEP_WIDTH    DERIVED                   true

  add_parameter           DATAUSER_WIDTH    INTEGER                   1
  set_parameter_property  DATAUSER_WIDTH    DISPLAY_NAME              "Datauser Width"
  set_parameter_property  DATAUSER_WIDTH    AFFECTS_ELABORATION       true
  set_parameter_property  DATAUSER_WIDTH    ALLOWED_RANGES            {1 2}

  # Sensor RX Interfaces

  add_display_item "Sensor RX"  SENSOR_RX_IF_INST  parameter
  add_display_item "Sensor RX"  SIF_RX_DATA_GEN    parameter

  add_parameter           SENSOR_RX_IF_INST   INTEGER                 1
  set_parameter_property  SENSOR_RX_IF_INST   DISPLAY_NAME            "Sensor RX Interfaces"
  set_parameter_property  SENSOR_RX_IF_INST   ALLOWED_RANGES          0:32
  set_parameter_property  SENSOR_RX_IF_INST   AFFECTS_ELABORATION     true

  add_parameter           SIF_RX_DATA_GEN     INTEGER                 0
  set_parameter_property  SIF_RX_DATA_GEN     DISPLAY_NAME            "Data Generator"
  set_parameter_property  SIF_RX_DATA_GEN     DISPLAY_HINT            boolean
  set_parameter_property  SIF_RX_DATA_GEN     AFFECTS_ELABORATION     false

  for {set inst 0} {$inst < 32} {incr inst} {
    add_display_item "Sensor RX"  "RX $inst"  group tab
    add_display_item "RX $inst"  SIF_RX_${inst}_WIDTH    parameter
    add_display_item "RX $inst"  SIF_RX_${inst}_PACKETIZER_EN    parameter

    add_parameter           SIF_RX_${inst}_WIDTH            INTEGER               8
    set_parameter_property  SIF_RX_${inst}_WIDTH            DISPLAY_NAME          "Sensor RX ${inst} Data Width"
    set_parameter_property  SIF_RX_${inst}_WIDTH            ALLOWED_RANGES        {8 16 32 64 128 256 512 1024}
    set_parameter_property  SIF_RX_${inst}_WIDTH            AFFECTS_ELABORATION   true

    add_parameter           SIF_RX_${inst}_PACKETIZER_EN    INTEGER               0
    set_parameter_property  SIF_RX_${inst}_PACKETIZER_EN    DISPLAY_NAME          "Sensor RX ${inst} Packetizer"
    set_parameter_property  SIF_RX_${inst}_PACKETIZER_EN    DISPLAY_HINT          boolean
    set_parameter_property  SIF_RX_${inst}_PACKETIZER_EN    AFFECTS_ELABORATION   false

    add_display_item "RX $inst"  "Packetizer $inst" group
    add_display_item "Packetizer $inst"  SIF_RX_${inst}_NUM_CYCLES       parameter
    add_display_item "Packetizer $inst"  SIF_RX_${inst}_SORT_RESOLUTION  parameter
    add_display_item "Packetizer $inst"  SIF_RX_${inst}_VP_COUNT         parameter
    add_display_item "Packetizer $inst"  SIF_RX_${inst}_VP_SIZE          parameter

    add_parameter           SIF_RX_${inst}_VP_COUNT         INTEGER               1
    set_parameter_property  SIF_RX_${inst}_VP_COUNT         DISPLAY_NAME          "Packetizer ${inst} VP Count"
    set_parameter_property  SIF_RX_${inst}_VP_COUNT         DESCRIPTION           "DO NOT TOUCH"
    set_parameter_property  SIF_RX_${inst}_VP_COUNT         AFFECTS_ELABORATION   false

    add_parameter           SIF_RX_${inst}_VP_SIZE          INTEGER               32
    set_parameter_property  SIF_RX_${inst}_VP_SIZE          DISPLAY_NAME          "Packetizer ${inst} VP Size"
    set_parameter_property  SIF_RX_${inst}_VP_SIZE          DESCRIPTION           "DO NOT TOUCH"
    set_parameter_property  SIF_RX_${inst}_VP_SIZE          AFFECTS_ELABORATION   false

    add_parameter           SIF_RX_${inst}_NUM_CYCLES       INTEGER               1
    set_parameter_property  SIF_RX_${inst}_NUM_CYCLES       DISPLAY_NAME          "Packetizer ${inst} Cycles"
    set_parameter_property  SIF_RX_${inst}_NUM_CYCLES       DESCRIPTION           "DO NOT TOUCH"
    set_parameter_property  SIF_RX_${inst}_NUM_CYCLES       AFFECTS_ELABORATION   false

    add_parameter           SIF_RX_${inst}_SORT_RESOLUTION  INTEGER               8
    set_parameter_property  SIF_RX_${inst}_SORT_RESOLUTION  DISPLAY_NAME          "Packetizer ${inst} Sort Resolution"
    set_parameter_property  SIF_RX_${inst}_SORT_RESOLUTION  DESCRIPTION           "DO NOT TOUCH"
    set_parameter_property  SIF_RX_${inst}_SORT_RESOLUTION  AFFECTS_ELABORATION   false
  }

  # Sensor TX Interfaces

  add_display_item "Sensor TX"  SENSOR_TX_IF_INST  parameter

  add_parameter           SENSOR_TX_IF_INST  INTEGER              1
  set_parameter_property  SENSOR_TX_IF_INST  DISPLAY_NAME         "Sensor TX Interfaces"
  set_parameter_property  SENSOR_TX_IF_INST  ALLOWED_RANGES       0:32
  set_parameter_property  SENSOR_TX_IF_INST  AFFECTS_ELABORATION  true

  for {set inst 0} {$inst < 32} {incr inst} {
    add_display_item "Sensor TX"  "TX $inst"  group tab
    add_display_item "TX $inst"  SIF_TX_${inst}_WIDTH    parameter
    add_display_item "TX $inst"  SIF_TX_${inst}_BUF_SIZE parameter

    add_parameter           SIF_TX_${inst}_WIDTH      INTEGER               8
    set_parameter_property  SIF_TX_${inst}_WIDTH      DISPLAY_NAME          "Sensor TX ${inst} Data Width"
    set_parameter_property  SIF_TX_${inst}_WIDTH      ALLOWED_RANGES        {8 64 512}
    set_parameter_property  SIF_TX_${inst}_WIDTH      AFFECTS_ELABORATION   true

    add_parameter           SIF_TX_${inst}_BUF_SIZE   INTEGER               1024
    set_parameter_property  SIF_TX_${inst}_BUF_SIZE   DISPLAY_NAME          "Sensor TX ${inst} Buffer Size"
    set_parameter_property  SIF_TX_${inst}_BUF_SIZE   ALLOWED_RANGES        {1024 2048 4096}
    set_parameter_property  SIF_TX_${inst}_BUF_SIZE   AFFECTS_ELABORATION   false
  }

  add_parameter           HOST_IF_INST          INTEGER               1
  set_parameter_property  HOST_IF_INST          DISPLAY_NAME          "Host Interfaces"
  set_parameter_property  HOST_IF_INST          ALLOWED_RANGES        1:32
  set_parameter_property  HOST_IF_INST          AFFECTS_ELABORATION   true

  add_parameter           HOST_WIDTH            INTEGER               8
  set_parameter_property  HOST_WIDTH            DISPLAY_NAME          "Host Width"
  set_parameter_property  HOST_WIDTH            AFFECTS_ELABORATION   true
  set_parameter_property  HOST_WIDTH            ALLOWED_RANGES        {8 16 32 64 128 256 512}

  add_parameter           HOSTKEEP_WIDTH        INTEGER               1
  set_parameter_property  HOSTKEEP_WIDTH        DISPLAY_NAME          "Hostkeep Width"
  set_parameter_property  HOSTKEEP_WIDTH        DESCRIPTION           "Host Width divided by 8"
  set_parameter_property  HOSTKEEP_WIDTH        AFFECTS_ELABORATION   true
  set_parameter_property  HOSTKEEP_WIDTH        DERIVED               true

  add_parameter           HOSTUSER_WIDTH        INTEGER               1
  set_parameter_property  HOSTUSER_WIDTH        DISPLAY_NAME          "Hostuser Width"
  set_parameter_property  HOSTUSER_WIDTH        AFFECTS_ELABORATION   true
  set_parameter_property  HOSTUSER_WIDTH        ALLOWED_RANGES        1
  set_parameter_property  HOSTUSER_WIDTH        ENABLED               false

  add_parameter           HOST_MTU              INTEGER               1500
  set_parameter_property  HOST_MTU              DISPLAY_NAME          "Host MTU"
  set_parameter_property  HOST_MTU              AFFECTS_ELABORATION   false
  set_parameter_property  HOST_MTU              ALLOWED_RANGES        {1500 4096}

  add_parameter           HIF_CLK_FREQ          POSITIVE              156250000
  set_parameter_property  HIF_CLK_FREQ          DISPLAY_NAME          "Host Interface Clock Frequency"
  set_parameter_property  HIF_CLK_FREQ          DISPLAY_UNITS         "Hz"
  set_parameter_property  HIF_CLK_FREQ          AFFECTS_ELABORATION   true

  add_parameter           SYNC_CLK_HIF_APB      INTEGER               0
  set_parameter_property  SYNC_CLK_HIF_APB      DISPLAY_NAME          "APB uses same clock as HIF"
  set_parameter_property  SYNC_CLK_HIF_APB      DISPLAY_HINT          boolean
  set_parameter_property  SYNC_CLK_HIF_APB      AFFECTS_ELABORATION   true

  add_parameter           APB_CLK_FREQ          POSITIVE              150000000
  set_parameter_property  APB_CLK_FREQ          DISPLAY_NAME          "APB Interface Clock Frequency"
  set_parameter_property  APB_CLK_FREQ          DISPLAY_UNITS         "Hz"
  set_parameter_property  APB_CLK_FREQ          ALLOWED_RANGES        20000000:1000000000
  set_parameter_property  APB_CLK_FREQ          AFFECTS_ELABORATION   true
  set_parameter_property  APB_CLK_FREQ          DERIVED               true
  set_parameter_property  APB_CLK_FREQ          VISIBLE               false

  add_parameter           APB_CLK_FREQ_GUI      POSITIVE              150000000
  set_parameter_property  APB_CLK_FREQ_GUI      DISPLAY_NAME          "APB Interface Clock Frequency"
  set_parameter_property  APB_CLK_FREQ_GUI      DISPLAY_UNITS         "Hz"
  set_parameter_property  APB_CLK_FREQ_GUI      ALLOWED_RANGES        20000000:1000000000
  set_parameter_property  APB_CLK_FREQ_GUI      AFFECTS_ELABORATION   true
  set_parameter_property  APB_CLK_FREQ_GUI      DERIVED               false
  set_parameter_property  APB_CLK_FREQ_GUI      VISIBLE               true

  add_parameter           SYNC_CLK_HIF_PTP      INTEGER               0
  set_parameter_property  SYNC_CLK_HIF_PTP      DISPLAY_NAME          "PTP uses same clock as HIF"
  set_parameter_property  SYNC_CLK_HIF_PTP      DISPLAY_HINT          boolean
  set_parameter_property  SYNC_CLK_HIF_PTP      AFFECTS_ELABORATION   true

  add_parameter           PTP_CLK_FREQ          POSITIVE              100000000
  set_parameter_property  PTP_CLK_FREQ          DISPLAY_NAME          "PTP Clock Frequency"
  set_parameter_property  PTP_CLK_FREQ          DISPLAY_UNITS         "Hz"
  set_parameter_property  PTP_CLK_FREQ          ALLOWED_RANGES        95000000:105000000
  set_parameter_property  PTP_CLK_FREQ          AFFECTS_ELABORATION   true
  set_parameter_property  PTP_CLK_FREQ          DERIVED               true
  set_parameter_property  PTP_CLK_FREQ          VISIBLE               false

  add_parameter           PTP_CLK_FREQ_GUI      POSITIVE              100000000
  set_parameter_property  PTP_CLK_FREQ_GUI      DISPLAY_NAME          "PTP Clock Frequency"
  set_parameter_property  PTP_CLK_FREQ_GUI      DISPLAY_UNITS         "Hz"
  set_parameter_property  PTP_CLK_FREQ_GUI      ALLOWED_RANGES        95000000:105000000
  set_parameter_property  PTP_CLK_FREQ_GUI      AFFECTS_ELABORATION   true
  set_parameter_property  PTP_CLK_FREQ_GUI      DERIVED               false
  set_parameter_property  PTP_CLK_FREQ_GUI      VISIBLE               true

  add_parameter           ENUM_EEPROM           INTEGER               0
  set_parameter_property  ENUM_EEPROM           DISPLAY_NAME          "Enumeration packet read from external EEPROM"
  set_parameter_property  ENUM_EEPROM           DISPLAY_HINT          boolean
  set_parameter_property  ENUM_EEPROM           AFFECTS_ELABORATION   true

  add_parameter           EEPROM_REG_ADDR_BITS  INTEGER               8
  set_parameter_property  EEPROM_REG_ADDR_BITS  DISPLAY_NAME          "EEPROM register address bits"
  set_parameter_property  EEPROM_REG_ADDR_BITS  ALLOWED_RANGES        {8 16}
  set_parameter_property  EEPROM_REG_ADDR_BITS  AFFECTS_ELABORATION   false
  set_parameter_property  EEPROM_REG_ADDR_BITS  ENABLED               false

  add_parameter           EXPOSE_ID             INTEGER               0
  set_parameter_property  EXPOSE_ID             DISPLAY_NAME          "Expose ID pins"
  set_parameter_property  EXPOSE_ID             DISPLAY_HINT          boolean
  set_parameter_property  EXPOSE_ID             AFFECTS_ELABORATION   true

  add_parameter           EXPOSE_ID_SINGLE_INTF  INTEGER              0
  set_parameter_property  EXPOSE_ID_SINGLE_INTF  DISPLAY_NAME         "ID as single interface"
  set_parameter_property  EXPOSE_ID_SINGLE_INTF  DISPLAY_HINT         boolean
  set_parameter_property  EXPOSE_ID_SINGLE_INTF  AFFECTS_ELABORATION  true

  for {set inst 0} {$inst < 32} {incr inst} {
    add_display_item "Enumeration" "MAC $inst"  group tab
    add_display_item "MAC $inst"  MAC_ADDR_${inst}    parameter

    add_parameter           MAC_ADDR_${inst}   STD_LOGIC_VECTOR          0
    set_parameter_property  MAC_ADDR_${inst}   DISPLAY_NAME              "Host $inst MAC Address"
    set_parameter_property  MAC_ADDR_${inst}   DISPLAY_UNITS             "48-bit"
    set_parameter_property  MAC_ADDR_${inst}   WIDTH                     48
    set_parameter_property  MAC_ADDR_${inst}   ALLOWED_RANGES            0:[expr {(1<<48)-1}]
    set_parameter_property  MAC_ADDR_${inst}   AFFECTS_ELABORATION       false
  }

  add_parameter           EXT_PTP               INTEGER               0
  set_parameter_property  EXT_PTP               DISPLAY_NAME          "External PTP"
  set_parameter_property  EXT_PTP               DISPLAY_HINT          boolean
  set_parameter_property  EXT_PTP               AFFECTS_ELABORATION   true

  add_parameter           NUM_SIF_EVENT  INTEGER                  1
  set_parameter_property  NUM_SIF_EVENT  DISPLAY_NAME             "Sensor event interfaces"
  set_parameter_property  NUM_SIF_EVENT  DISPLAY_UNITS            "out of 16"
  set_parameter_property  NUM_SIF_EVENT  ALLOWED_RANGES           0:16
  set_parameter_property  NUM_SIF_EVENT  AFFECTS_ELABORATION      true

  add_parameter           IND_SIF_EVENT  INTEGER                  1
  set_parameter_property  IND_SIF_EVENT  DISPLAY_NAME             "Individual sensor event interfaces"
  set_parameter_property  IND_SIF_EVENT  DISPLAY_HINT             boolean
  set_parameter_property  IND_SIF_EVENT  AFFECTS_ELABORATION      true

  add_parameter           NUM_SW_SEN_RST  INTEGER                 1
  set_parameter_property  NUM_SW_SEN_RST  DISPLAY_NAME            "Software sensor reset interfaces"
  set_parameter_property  NUM_SW_SEN_RST  DISPLAY_UNITS           "out of 32"
  set_parameter_property  NUM_SW_SEN_RST  ALLOWED_RANGES          0:32
  set_parameter_property  NUM_SW_SEN_RST  AFFECTS_ELABORATION     true

  add_parameter           IND_SW_SEN_RST  INTEGER                 1
  set_parameter_property  IND_SW_SEN_RST  DISPLAY_NAME            "Individual software sensor reset interfaces"
  set_parameter_property  IND_SW_SEN_RST  DISPLAY_HINT            boolean
  set_parameter_property  IND_SW_SEN_RST  AFFECTS_ELABORATION     true

  add_parameter           DEVICE                string                "Unknown"
  set_parameter_property  DEVICE                SYSTEM_INFO           {DEVICE}
  set_parameter_property  DEVICE                HDL_PARAMETER         false
  set_parameter_property  DEVICE                VISIBLE               false
}

################################################################################
# Add fixed IO
################################################################################
proc add_axi4s_interface { busname clk rst {dir slave} {data_width ""} {user_width ""} {keep_width ""}}  {

  if {${dir} == "master"} {
    set master_out "Output"
    set master_in  "Input"
    set direction  "start"
    set pre_i      "o_"
    set pre_o      "i_"
  } else {
    set master_out "Input"
    set master_in  "Output"
    set direction  "end"
    set pre_i      "i_"
    set pre_o      "o_"
  }

  set parameter_busname "C_[string toupper ${busname}]"

  if { ${data_width} == "" } {
    set data_width  ${parameter_busname}_TDATA_WIDTH
  }

  if { ${user_width} == "" } {
    set user_width  ${parameter_busname}_TUSER_WIDTH
  }

  add_interface ${busname} axi4stream ${direction}
  set_interface_property ${busname} associatedClock ${clk}
  set_interface_property ${busname} associatedReset ${rst}

  add_interface_port ${busname} ${pre_i}${busname}_tvalid tvalid ${master_out} 1
  add_interface_port ${busname} ${pre_i}${busname}_tlast  tlast  ${master_out} 1
  add_interface_port ${busname} ${pre_i}${busname}_tdata  tdata  ${master_out} ${data_width}

  if { ${keep_width} != 0 } {
    if { ${keep_width} == "" } {
      set keep_width  [expr {${data_width}/8}]
    }
    add_interface_port ${busname} ${pre_i}${busname}_tkeep  tkeep  ${master_out} ${keep_width}
  }

  add_interface_port ${busname} ${pre_i}${busname}_tuser  tuser  ${master_out} ${user_width}
  add_interface_port ${busname} ${pre_o}${busname}_tready tready ${master_in}  1

  set_port_property ${pre_i}${busname}_tuser VHDL_TYPE STD_LOGIC_VECTOR

}

################################################################################
# Add axis bus that doesn't have tkeep
################################################################################
proc add_axi4s_interface_nokeep { busname clk rst {dir slave} {data_width ""} {user_width ""}}  {
  add_axi4s_interface $busname $clk $rst $dir $data_width $user_width 0
}

proc add_reset_interface {intf port {dir sink} {clock ""} {edge none} {associatedreset ""} {role reset}} {
  if {$dir == "sink"} {
    set port_dir Input
  } else {
    set port_dir Output
  }
  add_interface          $intf reset $dir
  add_interface_port     $intf $port $role $port_dir 1
  set_interface_property $intf associatedClock       $clock
  set_interface_property $intf synchronousEdges      $edge
  if {$dir == "source"} {
    set_interface_property $intf associatedDirectReset $associatedreset
    set_interface_property $intf associatedResetSinks  $associatedreset
  }
}

################################################################################
# Add fixed IO
################################################################################
proc add_fixed_io { } {

  add_reset_interface     i_sys_rst i_sys_rst sink "" none

  # Auto Init Done
  add_interface           o_init_done   conduit           end
  add_interface_port      o_init_done   o_init_done       init_done   Output 1

  # New in 2507, PTP clock and reset
  add_interface           i_ptp_clk   clock             sink
  add_interface_port      i_ptp_clk   i_ptp_clk         clk         Input  1

  add_reset_interface     o_ptp_rst o_ptp_rst source i_ptp_clk deassert i_sys_rst
}

################################################################################
# Prepend list function, needed to order configuration arrays {n, n-1, ... 0}
################################################################################
proc lprepend {listName element} {
    upvar 1 $listName list
    set list [linsert [expr {[info exists list] ? $list : ""}] 0 $element]
}

################################################################################
# Process Terp Files
################################################################################
proc add_terp { outputName dest_dir {sim 0 } } {

  set file_lst [glob -nocomplain -- "./*.sv.terp"]
  foreach file ${file_lst} {
    set filename [file tail [file rootname ${file}]]

    if {${outputName} != ""} {
      set filename "${outputName}.sv"
    }
    add_fileset_file ${dest_dir}${filename} SYSTEM_VERILOG TEXT [terp_file ${file}]
  }
}

################################################################################
# Add Source files
################################################################################
proc add_source_files { outputName } {

  set init_reg [parse_init_reg_file]
  if {$init_reg == -1} {
    send_message error "Error parsing initialization register file"
  }

  set nv_hsb_ip_search_path [get_nv_hsb_ip_loc]
  # Use nested glob to find all .sv and .v files recursively
  set file_lst {}
  if {[file isdirectory ${nv_hsb_ip_search_path}]} {
    set subdirs [glob -nocomplain -types d -directory ${nv_hsb_ip_search_path} *]
    foreach subdir ${subdirs} {
      set files [glob -nocomplain -types f -directory ${subdir} *]
      foreach file ${files} {
        lappend file_lst ${file}
      }
    }
    send_message info "Found [llength ${file_lst}] files in nv_hsb_ip subdirectories"
  } else {
    send_message error "nv_hsb_ip directory not found"
  }
  foreach file ${file_lst} {
    set file_name [file tail ${file}]
    if {[regexp {i2s} ${file_name}]} {
      continue
    }
    if {[regexp {\.sv$|\.v$} ${file_name}]} {
      add_fileset_file "rtl/${file_name}" SYSTEM_VERILOG PATH ${file}
    }
  }

  add_fileset_file "rtl/HOLOLINK_def.svh" SYSTEM_VERILOG TEXT [terp_file "HOLOLINK_def.svh.terp"]
  add_terp ${outputName} "./"
}

################################################################################
# Parse Initialization Register File
################################################################################
proc parse_init_reg_file {} {
  set file_name [get_parameter_value INIT_REG_FILE]
  set file_format [get_parameter_value INIT_REG_FILE_FORMAT]
  if {$file_name == ""} {
    return {}
  }
  send_message info "Parsing initialization register $file_format file $file_name"

  set init_reg {}
  set n_init_reg 0
  set fh [open $file_name]
  set line_number 0
  set err 0

  if {$file_format == "Text"} {
    # Regex for matching a 32-bit hex
    set re_hex {^(?:0[xX])?[[:xdigit:]](?:[_-]?[[:xdigit:]]){7}$}

    # Regex for matching a # or // comment
    set re_cmt {^[\/]{2}|#}

    while {[gets $fh line] != -1} {
      incr line_number
      set line_split [split $line { ,\t}]
      set line_parsed {}
      foreach tok $line_split {
        if {[regexp $re_cmt $tok]} {
          break
        }
        if {[regexp $re_hex $tok]} {
          lappend line_parsed [string map {0x "" 0X "" _ ""} $tok]
        }
      }
      if {[scan $line_parsed "%x %x" address data] == 2} {
        incr n_init_reg
        lappend init_reg "$address $data"
      }
    }
  } else {
    while {[gets $fh line] != -1} {
      incr line_number
      set matches [scan $line ":%02x%04x%02x%s" byte_count address type rest]
      if {$byte_count > 0} {
        incr matches [scan $rest "%0[expr {2*$byte_count}]x%02x" data checksum]
        if {$matches != 6} {
          send_message error "Error parsing line $line_number in $file_name"
          incr err
          continue
        }
      } else {
        incr matches [scan $rest "%02x" checksum]
        if {$matches != 5} {
          send_message error "Error parsing line $line_number in $file_name"
          incr err
          continue
        }
      }

      # verify checksum
      set sum 0
      set str [string range $line 1 end]
      while {[scan $str %02x byte] > 0} {
        incr sum $byte
        set str [string range $str 2 end]
      }
      if {[expr {$sum & 0xff}] != 0} {
        set expected [expr {~($sum-$checksum)+1 & 0xff}]
        send_message error "Bad checksum on line $line_number in $file_name"
        send_message error [format "Found 0x%02X, expected 0x%02X" $checksum $expected]
        incr err
      }

      # interpret data based on type
      switch $type {
        4 {
          # Extended Linear Address
          set ela $data
        }
        0 {
          # Data
          incr n_init_reg
          lappend init_reg "[expr {($ela<<16)+$address}] $data"
        }
        1 {
          # End Of File
          break
        }
      }
    }
  }
  if {$err > 0} {
    send_message error "$err errors detected"
    return -1
  } else {
    if {$n_init_reg > 0} {
      send_message info "Done: $n_init_reg register write[expr {$n_init_reg>1?"s":""}] found"
      set i 0
      foreach line $init_reg {
        incr i
        send_message info [format "$i: 0x%08X, 0x%08X" {*}$line]
      }
    } else {
      send_message warning "Done: no register writes found"
    }
    return $init_reg
  }
}

################################################################################
# Elaboration Callback - Create fixed I/O and evaluate widths of signals.
################################################################################
proc elab_callback { } {
  set uart_inst               [get_parameter_value UART_INST]
  set spi_inst                [get_parameter_value SPI_INST]
  set gpio_inst               [get_parameter_value GPIO_INST]
  set i2c_inst                [get_parameter_value I2C_INST]
  set reg_inst                [get_parameter_value REG_INST]
  set datauser_width          [get_parameter_value DATAUSER_WIDTH]
  set sensor_rx_if_inst       [get_parameter_value SENSOR_RX_IF_INST]
  set sensor_tx_if_inst       [get_parameter_value SENSOR_TX_IF_INST]
  set host_if_inst            [get_parameter_value HOST_IF_INST]
  set host_width              [get_parameter_value HOST_WIDTH]
  set hostkeep_width          [get_parameter_value HOSTKEEP_WIDTH]
  set hostuser_width          [get_parameter_value HOSTUSER_WIDTH]
  set enum_eeprom             [get_parameter_value ENUM_EEPROM]
  set expose_id               [get_parameter_value EXPOSE_ID]
  set ext_ptp                 [get_parameter_value EXT_PTP]

  # HIF - Host Interfaces
  add_interface          i_hif_clk    clock         sink
  add_interface_port     i_hif_clk    i_hif_clk     clk Input    1

  add_reset_interface    o_hif_rst o_hif_rst source i_hif_clk deassert i_sys_rst

  for {set inst 0} {${inst} < ${host_if_inst}} {incr inst} {
    add_axi4s_interface hif_rx_${inst}_axis i_hif_clk o_hif_rst slave  $host_width $hostuser_width $hostkeep_width
    add_axi4s_interface hif_tx_${inst}_axis i_hif_clk o_hif_rst master $host_width $hostuser_width $hostkeep_width
  }

  if {!$enum_eeprom && $expose_id} {
    if {[get_parameter_value EXPOSE_ID_SINGLE_INTF]} {
      # As one interface
      add_interface id conduit end
      for {set inst 0} {${inst} < ${host_if_inst}} {incr inst} {
        # Note, can't have more than one instance of same port role in interface
        add_interface_port id i_mac_addr_${inst} mac_addr_${inst} Input 48
      }
      add_interface_port id i_board_sn board_sn Input 56
      add_interface_port id i_enum_vld enum_vld Input 1
    } else {
      # As separate interfaces
      for {set inst 0} {${inst} < ${host_if_inst}} {incr inst} {
        add_interface      i_mac_addr_${inst} conduit end
        add_interface_port i_mac_addr_${inst} i_mac_addr_${inst} mac_addr Input 48
      }
      add_interface      i_board_sn conduit end
      add_interface_port i_board_sn i_board_sn board_sn Input 56

      add_interface      i_enum_vld conduit end
      add_interface_port i_enum_vld i_enum_vld enum_vld Input 1
    }
  }

  # PTP Status
  if {$ext_ptp} {
    add_interface      i_ptp  conduit       end
    add_interface_port i_ptp  i_ptp_sec     ptp_sec         Input       48
    add_interface_port i_ptp  i_ptp_nanosec ptp_nanosec     Input       32
  } else {
    add_interface      o_ptp  conduit       end
    add_interface_port o_ptp  o_ptp_sec     ptp_sec         Output      48
    add_interface_port o_ptp  o_ptp_nanosec ptp_nanosec     Output      32

    #add_interface      o_pps  conduit       end
    add_interface_port o_ptp  o_pps         pps             Output      1
  }

  # SIF RX - Sensor RX Interfaces
  for {set inst 0} {${inst} < ${sensor_rx_if_inst}} {incr inst} {
    add_interface          i_sif_rx_${inst}_clk   clock              sink
    add_interface_port     i_sif_rx_${inst}_clk   i_sif_rx_${inst}_clk clk Input 1

    add_reset_interface    o_sif_rx_${inst}_rst o_sif_rx_${inst}_rst source i_sif_rx_${inst}_clk deassert i_sys_rst

    set data_width [get_parameter_value SIF_RX_${inst}_WIDTH]
    add_axi4s_interface    sif_rx_${inst}_axis  i_sif_rx_${inst}_clk o_sif_rx_${inst}_rst slave $data_width $datauser_width 
  }

  # SIF TX - Sensor TX Interfaces
  for {set inst 0} {${inst} < ${sensor_tx_if_inst}} {incr inst} {
    add_interface          i_sif_tx_${inst}_clk   clock              sink
    add_interface_port     i_sif_tx_${inst}_clk   i_sif_tx_${inst}_clk clk Input 1

    add_reset_interface    o_sif_tx_${inst}_rst o_sif_tx_${inst}_rst source i_sif_tx_${inst}_clk deassert i_sys_rst

    set data_width [get_parameter_value SIF_TX_${inst}_WIDTH]
    add_axi4s_interface    sif_tx_${inst}_axis  i_sif_tx_${inst}_clk o_sif_tx_${inst}_rst master $data_width $datauser_width
  }

  # SIF Event
  if {[get_parameter_value IND_SIF_EVENT]} {
    for {set inst 0} {$inst < [get_parameter_value NUM_SIF_EVENT]} {incr inst} {
      add_interface       i_sif_event_${inst}    interrupt receiver
      add_interface_port  i_sif_event_${inst}    i_sif_event_${inst}   irq  Input  1
    }
  } else {
    if {[get_parameter_value NUM_SIF_EVENT] > 0} {
      add_interface       i_sif_event    interrupt receiver
      add_interface_port  i_sif_event    i_sif_event   irq  Input  [get_parameter_value NUM_SIF_EVENT]
    }
  }

  # SW Sys Reset
  add_reset_interface     o_sw_sys_rst  o_sw_sys_rst source i_hif_clk both i_sys_rst

  # Sensor Reset
  if {[get_parameter_value IND_SW_SEN_RST]} {
    for {set inst 0} {$inst < [get_parameter_value NUM_SW_SEN_RST]} {incr inst} {
      add_reset_interface     o_sw_sen_rst_${inst}  o_sw_sen_rst_${inst} source i_hif_clk both i_sys_rst
    }
  } else {
    if {[get_parameter_value NUM_SW_SEN_RST] > 0} {
      add_interface       o_sw_sen_rst   conduit       end
      add_interface_port  o_sw_sen_rst   o_sw_sen_rst  sw_sen_rst Output [get_parameter_value NUM_SW_SEN_RST]
    }
  }

  for {set inst 0} {${inst} < ${spi_inst}} {incr inst} {
    # SPI Interface
    add_interface      spi_${inst} conduit            end
    add_interface_port spi_${inst} o_spi_${inst}_csn  o_spi_csn   Output 1
    add_interface_port spi_${inst} o_spi_${inst}_sck  o_spi_sck   Output 1
    add_interface_port spi_${inst} i_spi_${inst}_sdio i_spi_sdio  Input  4
    add_interface_port spi_${inst} o_spi_${inst}_sdio o_spi_sdio  Output 4
    add_interface_port spi_${inst} o_spi_${inst}_oen  o_spi_oen   Output 1
  }

  for {set inst 0} {${inst} < ${i2c_inst}} {incr inst} {
    # I2C Interface
    add_interface      i2c_${inst} conduit              end
    add_interface_port i2c_${inst} i_i2c_${inst}_scl    i_i2c_scl    Input  1
    add_interface_port i2c_${inst} i_i2c_${inst}_sda    i_i2c_sda    Input  1
    add_interface_port i2c_${inst} o_i2c_${inst}_scl_en o_i2c_scl_en Output 1
    add_interface_port i2c_${inst} o_i2c_${inst}_sda_en o_i2c_sda_en Output 1
  }

  # UART Interface
  if {$uart_inst > 0} {
    add_interface           uart         conduit          end
    add_interface_port      uart         o_uart_tx        o_uart_tx   Output 1
    add_interface_port      uart         i_uart_rx        i_uart_rx   Input  1
    add_interface_port      uart         o_uart_busy      o_uart_busy Output 1
    add_interface_port      uart         i_uart_cts       i_uart_cts  Input  1
    add_interface_port      uart         o_uart_rts       o_uart_rts  Output 1
  }

  # GPIO Interface
  if {$gpio_inst > 0} {
    add_interface           gpio         conduit         end
    add_interface_port      gpio         o_gpio          o_gpio Output ${gpio_inst}
    add_interface_port      gpio         i_gpio          i_gpio Input  ${gpio_inst}
  }

  # APB Interface
  add_interface           i_apb_clk    clock            sink
  add_interface_port      i_apb_clk    i_apb_clk        clk           Input  1

  add_reset_interface     o_apb_rst  o_apb_rst source i_apb_clk deassert i_sys_rst

  for {set inst 0} {${inst} < ${reg_inst}} {incr inst} {
    add_interface          apb_${inst} apb                      start
    set_interface_property apb_${inst} associatedClock          i_apb_clk
    set_interface_property apb_${inst} associatedReset          o_apb_rst
    add_interface_port     apb_${inst} o_apb_${inst}_psel       psel       Output 1
    add_interface_port     apb_${inst} o_apb_${inst}_penable    penable    Output 1
    add_interface_port     apb_${inst} o_apb_${inst}_paddr      paddr      Output 32
    add_interface_port     apb_${inst} o_apb_${inst}_pwdata     pwdata     Output 32
    add_interface_port     apb_${inst} o_apb_${inst}_pwrite     pwrite     Output 1
    add_interface_port     apb_${inst} i_apb_${inst}_pready     pready     Input  1
    add_interface_port     apb_${inst} i_apb_${inst}_prdata     prdata     Input  32
    add_interface_port     apb_${inst} i_apb_${inst}_pserr      pslverr    Input  1
  }

}

################################################################################
# Validation Callback - Report invalid settings and enable/disable parameters
################################################################################
proc val_callback { } {
  set gpio_inst  [get_parameter_value GPIO_INST]
  if {$gpio_inst == 0} {
    set_parameter_property GPIO_RESET_VALUE ENABLED false
  } else {
    set_parameter_property GPIO_RESET_VALUE ENABLED true

    # Validate GPIO reset value binary or hexadecimal string
    set gpio_raw   [get_parameter_value GPIO_RESET_VALUE]
    if {[regexp {^0[xX][[:xdigit:]](?:_?[[:xdigit:]])*$} $gpio_raw]} {
      # hex
      set gpio_nibbles [expr {($gpio_inst+3)/4}]
      set hex_str [string map {0x "" 0X "" _ ""} $gpio_raw]
      scan $hex_str %llx gpio

      if {[string length $hex_str] > $gpio_nibbles || $gpio > [expr {(1<<$gpio_inst)-1}]} {
        send_message error "Width of hex GPIO reset value $gpio_raw must not exceed GPIO interface width of $gpio_inst"
      }
    } elseif {[regexp {^0[bB][01](?:_?[01])*$} $gpio_raw]} {
      # bin
      set bin_str [string map {0b "" 0B "" _ ""} $gpio_raw]

      if {[string length $bin_str] > $gpio_inst} {
        send_message error "Width of binary GPIO reset value $gpio_raw must not exceed GPIO interface width of $gpio_inst"
      }
    } else {
      send_message error "Invalid GPIO reset value string \"$gpio_raw\""
    }
  }

  set datapath_width [get_parameter_value DATAPATH_WIDTH]
  set sensor_rx_if_inst    [get_parameter_value SENSOR_RX_IF_INST]
  if {$sensor_rx_if_inst > 0} {
    set_parameter_property SIF_RX_DATA_GEN ENABLED true
  } else {
    set_parameter_property SIF_RX_DATA_GEN ENABLED false
  }

  for {set inst 0} {$inst < 32} {incr inst} {
    if {$inst < $sensor_rx_if_inst} {
      set_display_item_property "RX $inst" VISIBLE true

      set width [get_parameter_value SIF_RX_${inst}_WIDTH]

      if {$width > $datapath_width} {
        send_message ERROR "Sensor RX interface $inst width $width must not exceed datapath width $datapath_width"
      }

      if {[get_parameter_value SIF_RX_${inst}_PACKETIZER_EN]} {
        set_display_item_property "Packetizer $inst" VISIBLE true
      } else {
        set_display_item_property "Packetizer $inst" VISIBLE false
      }
    } else {
      set_display_item_property "RX $inst" VISIBLE false
    }
  }

  set sensor_tx_if_inst    [get_parameter_value SENSOR_TX_IF_INST]
  for {set inst 0} {$inst < 32} {incr inst} {
    if {$inst < $sensor_tx_if_inst} {
      set_display_item_property "TX $inst" VISIBLE true

      set width [get_parameter_value SIF_TX_${inst}_WIDTH]
      if {$width > $datapath_width} {
        send_message ERROR "Sensor TX interface $inst width $width must not exceed datapath width $datapath_width"
      }
    } else {
      set_display_item_property "TX $inst" VISIBLE false
    }
  }

  set enum_eeprom     [get_parameter_value ENUM_EEPROM]
  set expose_id       [get_parameter_value EXPOSE_ID]
  if {$enum_eeprom} {
    set_parameter_property EEPROM_REG_ADDR_BITS  ENABLED true
    set_parameter_property EXPOSE_ID             ENABLED false
    set_parameter_property EXPOSE_ID_SINGLE_INTF ENABLED false
    set_parameter_property BOARD_SN              ENABLED false
  } else {
    set_parameter_property EEPROM_REG_ADDR_BITS  ENABLED false
    set_parameter_property EXPOSE_ID             ENABLED true
    if {$expose_id} {
      set_parameter_property EXPOSE_ID_SINGLE_INTF ENABLED true
      set_parameter_property BOARD_SN              ENABLED false
    } else {
      set_parameter_property EXPOSE_ID_SINGLE_INTF ENABLED false
      set_parameter_property BOARD_SN              ENABLED true
    }
  }

  set host_if_inst    [get_parameter_value HOST_IF_INST]
  for {set inst 0} {$inst < 32} {incr inst} {
    if {$inst < $host_if_inst} {
      if {!$enum_eeprom && !$expose_id} {
        set_parameter_property MAC_ADDR_$inst ENABLED true
      } else {
        set_parameter_property MAC_ADDR_$inst ENABLED false
      }
      set_display_item_property "MAC $inst" VISIBLE true
    } else {
      set_display_item_property "MAC $inst" VISIBLE false
    }
  }

  set datapath_width [get_parameter_value DATAPATH_WIDTH]
  set_parameter_value DATAKEEP_WIDTH [expr {$datapath_width/8}]

  set host_width [get_parameter_value HOST_WIDTH]
  set_parameter_value HOSTKEEP_WIDTH [expr {$host_width/8}]

  if {[get_parameter_value NUM_SIF_EVENT] > 0} {
    set_parameter_property IND_SIF_EVENT ENABLED true
  } else {
    set_parameter_property IND_SIF_EVENT ENABLED false
  }

  if {[get_parameter_value NUM_SW_SEN_RST] > 0} {
    set_parameter_property IND_SW_SEN_RST ENABLED true
  } else {
    set_parameter_property IND_SW_SEN_RST ENABLED false
  }

  # if apb or ptp clock synced with hif clock, force to be same as hif clock and disable as parameter
  set hif_clk_freq     [get_parameter_value HIF_CLK_FREQ]
  set apb_clk_freq_gui [get_parameter_value APB_CLK_FREQ_GUI]
  if {[get_parameter_value SYNC_CLK_HIF_APB] > 0} {
    set_parameter_property  APB_CLK_FREQ      VISIBLE true
    set_parameter_property  APB_CLK_FREQ_GUI  VISIBLE false
    set_parameter_value     APB_CLK_FREQ      $hif_clk_freq
  } else {
    set_parameter_property  APB_CLK_FREQ      VISIBLE false
    set_parameter_property  APB_CLK_FREQ_GUI  VISIBLE true
    set_parameter_value     APB_CLK_FREQ $apb_clk_freq_gui
  }
  
  set ptp_clk_freq_gui [get_parameter_value PTP_CLK_FREQ_GUI]
  if {[get_parameter_value SYNC_CLK_HIF_PTP] > 0} {
    set_parameter_property  PTP_CLK_FREQ      VISIBLE true
    set_parameter_property  PTP_CLK_FREQ_GUI  VISIBLE false
    set_parameter_value     PTP_CLK_FREQ      $hif_clk_freq
  } else {
    set_parameter_property  PTP_CLK_FREQ      VISIBLE false
    set_parameter_property  PTP_CLK_FREQ_GUI  VISIBLE true
    set_parameter_value     PTP_CLK_FREQ      $ptp_clk_freq_gui
  }

  get_nv_hsb_ip_loc

}

proc get_nv_hsb_ip_loc {} {
  # locating and verifying NVIDIA HSB IP source folder
  # check for environment variable (using catch for safety)
  if {[catch {set nv_hsb_ip_loc $::env(NV_HSB_IP_DIR)} err] == 0} {
    # Variable exists and was read successfully
    set nv_hsb_ip_loc [file normalize ${nv_hsb_ip_loc}]
    set nv_hsb_ip_search_path [file join ${nv_hsb_ip_loc} nv_hsb_ip]
    send_message INFO "NV_HSB_IP_DIR environment variable set"
  } else {
    # Variable doesn't exist or read failed
    set nv_hsb_ip_search_path "../../../../../../nv_hsb_ip"
    send_message INFO "NV_HSB_IP_DIR environment variable not set, using default"
  }

  if {[file isdirectory ${nv_hsb_ip_search_path}]} {
    send_message INFO "nv_hsb_ip folder found at expected location"  
  } else {
    send_message ERROR "nv_hsb_ip folder not found in expected location"
  }

  return $nv_hsb_ip_search_path
}

################################################################################
# Terp any file based on all the IP parameters
################################################################################
proc terp_file { src } {

  upvar ed_name    ed_name
  upvar sim        sim
  upvar outputName outputName

  set terp_fd       [open ${src}]
  set terp_contents [read ${terp_fd}]
  close ${terp_fd}

  set params {\
    BUILD_REV \
    UUID \
    BOARD_ID \
    BOARD_SN \
    I2C_INST \
    GPIO_INST \
    GPIO_RESET_VALUE \
    UART_INST \
    SPI_INST \
    REG_INST \
    DATAPATH_WIDTH \
    DATAKEEP_WIDTH \
    DATAUSER_WIDTH \
    SENSOR_RX_IF_INST \
    SIF_RX_DATA_GEN \
    SENSOR_TX_IF_INST \
    HOST_IF_INST \
    HOST_WIDTH \
    HOSTKEEP_WIDTH \
    HOSTUSER_WIDTH \
    HOST_MTU \
    HIF_CLK_FREQ \
    SYNC_CLK_HIF_PTP \
    PTP_CLK_FREQ \
    SYNC_CLK_HIF_APB \
    APB_CLK_FREQ \
    ENUM_EEPROM \
    EEPROM_REG_ADDR_BITS \
    EXPOSE_ID \
    EXT_PTP \
    IND_SIF_EVENT \
    NUM_SIF_EVENT \
    IND_SW_SEN_RST \
    NUM_SW_SEN_RST \
  }

  foreach param ${params} {
    set terp_params([string tolower ${param}]) [get_parameter_value ${param}]
  }

  # Sensor RX

  set terp_params(sif_rx_width) {}
  for {set inst 0} {$inst < [get_parameter_value SENSOR_RX_IF_INST]} {incr inst} {
    lprepend terp_params(sif_rx_width) [get_parameter_value SIF_RX_${inst}_WIDTH]
  }

  set terp_params(sif_rx_packetizer_en) {}
  for {set inst 0} {$inst < [get_parameter_value SENSOR_RX_IF_INST]} {incr inst} {
    lprepend terp_params(sif_rx_packetizer_en) [get_parameter_value SIF_RX_${inst}_PACKETIZER_EN]
  }

  set terp_params(sif_rx_vp_count) {}
  for {set inst 0} {$inst < [get_parameter_value SENSOR_RX_IF_INST]} {incr inst} {
    lprepend terp_params(sif_rx_vp_count) [get_parameter_value SIF_RX_${inst}_VP_COUNT]
  }
  set terp_params(sif_rx_vp_size) {}
  for {set inst 0} {$inst < [get_parameter_value SENSOR_RX_IF_INST]} {incr inst} {
    lprepend terp_params(sif_rx_vp_size) [get_parameter_value SIF_RX_${inst}_VP_SIZE]
  }
  set terp_params(sif_rx_num_cycles) {}
  for {set inst 0} {$inst < [get_parameter_value SENSOR_RX_IF_INST]} {incr inst} {
    lprepend terp_params(sif_rx_num_cycles) [get_parameter_value SIF_RX_${inst}_NUM_CYCLES]
  }
  set terp_params(sif_rx_sort_resolution) {}
  for {set inst 0} {$inst < [get_parameter_value SENSOR_RX_IF_INST]} {incr inst} {
    lprepend terp_params(sif_rx_sort_resolution) [get_parameter_value SIF_RX_${inst}_SORT_RESOLUTION]
  }

  # Sensor TX

  set terp_params(sif_tx_width) {}
  for {set inst 0} {$inst < [get_parameter_value SENSOR_TX_IF_INST]} {incr inst} {
    lprepend terp_params(sif_tx_width) [get_parameter_value SIF_TX_${inst}_WIDTH]
  }

  set terp_params(sif_tx_buf_size) {}
  for {set inst 0} {$inst < [get_parameter_value SENSOR_TX_IF_INST]} {incr inst} {
    lprepend terp_params(sif_tx_buf_size) [get_parameter_value SIF_TX_${inst}_BUF_SIZE]
  }

  # MAC Addresses

  set terp_params(mac_addr) {}
  for {set inst 0} {$inst < [get_parameter_value HOST_IF_INST]} {incr inst} {
    lappend terp_params(mac_addr) [get_parameter_value MAC_ADDR_${inst}]
  }

  if {[info exists outputName]} {
    set terp_params(output_name) ${outputName}
  }

  # Init Reg

  upvar init_reg init_reg
  if {[info exists init_reg]} {
    set terp_params(init_reg) $init_reg
  }

  return [ altera_terp ${terp_contents} terp_params]
}

add_fileset synth QUARTUS_SYNTH add_source_files

create_ui
add_fixed_io
