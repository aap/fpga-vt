set_global_assignment -entity "pll80" -library "lib_pll80" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "pll80" -library "lib_pll80" -name IP_TOOL_VERSION "18.0"
set_global_assignment -entity "pll80" -library "lib_pll80" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_pll80" -name SPD_FILE [file join $::quartus(sip_path) "pll80.spd"]

set_global_assignment -library "lib_pll80" -name MISC_FILE [file join $::quartus(sip_path) "pll80_sim/pll80.vo"]
