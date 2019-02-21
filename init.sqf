
hint "Initializing";

PID_fnc_Init = compile preprocessFile "PID_init.sqf";
PID_fnc_Calculate = compile preprocessFile "PID_calculate.sqf";

[] execVM "convoy\convoyInit.sqf";
//Execute scripts
//[] execVM "VCOM_Driving\init.sqf";