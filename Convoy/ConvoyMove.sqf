// ConvoyMove.sqf
// � v.2.5 MARCH 2016 - Devastator_cm

if (!isServer) exitWith {};

private _markerArray 		 	= _this select 0;
private _convoyArray 		 	= _this select 1;
private _ConvoySpeedLimit		= _this select 2;
private _ConvoySearchRange		= _this select 3;
private _ConvoyID 				= _this select 4;
private _ConvoySpeedMode		= _this select 5;
private _ConvoyBehaviour		= _this select 6;
private _StopConvoy  			= false;
private _marker 			 	= _markerArray select 0;
private _leadVcl 			 	= _convoyArray select 0;
private _markersRemaining 	 	= _markerArray;
private _all_groups 			= [];
private _inf_groups 			= [];
//private _arm_groups 			= [];
private _arm_vehicles           = [];
private _aliveConvoy 		 	= [];
private _c 					 	= 0;
private _i 					 	= 0;
private _ConvoyDestination		= false;
private _SplitArmored 			= objNull;
private _tmpGroup 				= [];
private _BaseGroup 				= objNull;
private _group 					= objNull;
private _crew					= objNull;
private _vehicle				= objNull;
private _enemySides				= _leadVcl call BIS_fnc_enemySides;

diag_log format ["[ConvoyMove %1] started", _ConvoyID];

diag_log format ["[ConvoyMove %1] fixing groups", _ConvoyID];

private _crewGroup = createGroup side driver _leadVcl;

{
    if ((_x isKindOf "Tank") || (!isNull (gunner (vehicle _x))) ) then 
    { 
        diag_log format ["[ConvoyMove %1] %2 is a tank", _ConvoyID, _x];
        //_arm_groups 	pushBack (group driver _x); 
        _arm_vehicles 	pushBack _x;
    };
    _crew = crew _x;

    // _tmpGroup = [];
    // {
    //     _tmpGroup pushBackUnique (group _x);
    // } foreach _crew;
    // if(count _tmpGroup != 1) then
    // {
    //     _BaseGroup =  _tmpGroup select 0;
    //     {
    //         units _x joinSilent _BaseGroup;
    //     } foreach (_tmpGroup select {_x != _BaseGroup}); 
    // };
    // _SplitArmored = objNull;

    for "_i" from 0 to (count _crew) - 1 step 1 do 
    {
        _unit = _crew select _i;
        //if((assignedVehicleRole _unit) select 0 == "Cargo" && group _unit == group driver (vehicle _x) && group driver (vehicle _x) in _arm_groups) then
        if((assignedVehicleRole _unit) select 0 == "Cargo" && group _unit != group driver (vehicle _x)) then
        { 
            diag_log format ["[ConvoyMove %1] %2 is transporting troops", _ConvoyID, _x];
            //if(isNull _SplitArmored) then {_SplitArmored 	= createGroup side _unit;};
            //[_unit] join (_SplitArmored);
            //diag_log format ["[ConvoyMove %1] %2 is moved to _SplitArmored", _ConvoyID, _unit];
            _all_groups pushBackUnique (group _unit); 
            _inf_groups pushBackUnique (group _unit); 
        } else {
            [_unit] joinSilent _crewGroup;
        };
        //_all_groups pushBackUnique (group _unit); 
    };
    //_inf_groups = _all_groups - _arm_groups;
} forEach _convoyArray;

_all_groups pushBack _crewGroup;

diag_log format ["[ConvoyMove %1] %2 groups, %3 inf", _ConvoyID, count _all_groups, count _inf_groups];

{
    while {(count (waypoints _x)) > 0} do {
        deleteWaypoint ((waypoints  _x) select 0);
    };
} foreach _all_groups;

{
    _group = _x;
    {
        if(rankId _x > rankId (leader _group)) then {
            _group selectLeader _x;
            diag_log format ["[ConvoyMove %1] %2 updated leader to %3", _ConvoyID, _group, _x];
        };
    } foreach units _group;
}	foreach _all_groups;

_i = 0;

{
    _x setVariable ["DEVAS_ConvoyAmbush",false,false];
    _x setVariable ["DEVAS_ConvoyDestination",false, false];
    _x setVariable ["DEVAS_ConvoyCurrentMarker",_marker,false];

    _x setSpeedMode "LIMITED";
    _x setBehaviour "SAFE";
    _x setCombatMode "GREEN";
    _x setConvoySeparation 30;
    
    _x limitSpeed _ConvoySpeedLimit;

    _x setVariable ["vehicleNudge", true, false];
    // _x doMove (getMarkerPos _marker);
    [_x, _markerArray select ((count _markerArray) -1), _convoyArray, _i, _ConvoySearchRange] spawn DEVAS_ConvoyMaxSpeed;
    _i = _i + 1;
}	forEach _convoyArray;

_convoyArray select (count _convoyArray - 1) limitSpeed _ConvoySpeedLimit;
_i = 0;

diag_log format ["[ConvoyMove %1] setting off", _ConvoyID];

[_convoyArray, 10] execVM "vehicleNudge.sqf";

_leadVcl setFormation "COLUMN";
_leadVcl move (getMarkerPos _marker);

while {!_StopConvoy} do 
{
    {
        _vehicle 	= _x;
        _enemies 	= (_vehicle neartargets _ConvoySearchRange) apply {_x select 4} select {side _x in _enemySides AND {count crew _x > 0} AND typeOf _x != "Logic" AND !(_x isKindOf "Air")};
        if (!alive _vehicle) then {
            _StopConvoy = true;
            diag_log format ["[ConvoyMove %1] STOPPING CONVOY: %2 is not alive", _ConvoyID, _vehicle];
        };
        if (!canMove _vehicle) then {
            _StopConvoy = true;
            diag_log format ["[ConvoyMove %1] STOPPING CONVOY: %2 cannot move", _ConvoyID, _vehicle];
        };
        if (!(_enemies isEqualTo [])) then {
            _StopConvoy = true;
            diag_log format ["[ConvoyMove %1] STOPPING CONVOY: enemies detected", _ConvoyID];
        };
        if (isNull driver _vehicle) then {
            _StopConvoy = true;
            diag_log format ["[ConvoyMove %1] STOPPING CONVOY: %2 has no driver", _ConvoyID, _vehicle];
        };
        if (!alive driver _vehicle) then {
            _StopConvoy = true;
            diag_log format ["[ConvoyMove %1] STOPPING CONVOY: %2 driver is dead", _ConvoyID, _vehicle];
        };
        if (_vehicle getVariable "DEVAS_ConvoyAmbush") then {
            _StopConvoy = true;
            diag_log format ["[ConvoyMove %1] STOPPING CONVOY: %2 is ambushed", _ConvoyID, _vehicle];
        };
        if (_vehicle getVariable "DEVAS_ConvoyDestination") then {
            _StopConvoy = true;
            _ConvoyDestination = true;
            diag_log format ["[ConvoyMove %1] STOPPING CONVOY: %2 reached destination", _ConvoyID, _vehicle];
        };
    } forEach _convoyArray;

    if (_StopConvoy) exitWith {};
    if ((_leadVcl distance (getMarkerPos _marker)) < 40) then 
    {
        diag_log format ["[ConvoyMove %1] Reached marker %2", _ConvoyID, _marker];
        if (count _markersRemaining > 1) then 
        {
            _marker = _markersRemaining select 1;
            _markersRemaining deleteAt (0);
            {
                //_x doMove getMarkerPos _marker;
                _x setVariable ["DEVAS_ConvoyCurrentMarker", _marker,false];
            } forEach _convoyArray;
            _leadVcl move (getMarkerPos _marker);
            _i = 0;
        }
    } else {
        if (_i == 0) then 
        {
            //{_x doMove getMarkerPos _marker} forEach _convoyArray;
            _leadVcl move (getMarkerPos _marker);
        };
    };
    if (_i == 10) then {_i = 0} else {_i = _i + 1}; 
    sleep 0.5;
};

if (_ConvoyDestination) then {
    [_convoyArray, _all_groups, _ConvoyID, _marker] spawn DEVAS_ConvoyEnd;
};

diag_log format ["[ConvoyMove %1] Stopping convoy before ambush response", _ConvoyID];

{
    _x setVariable ["DEVAS_ConvoyAmbush",true,false];
    //_x doMove (getPos _x);
    doStop _x;
    //_x limitspeed 10000;
    _x setVariable ["vehicleNudge", false, false];
} 	forEach (_convoyArray select {canMove _x});

if(!_ConvoyDestination) then
{
    {
        _aliveConvoy pushBack _x;
        _x setVariable ["DEVAS_ConvoyVclPos", getpos(_x), false];
        _x setVariable ["DEVAS_ConvoyVclDir", getDir(_x), false];
    } forEach (_convoyArray select {(alive _x && canMove _x)});

    // Split out armor crews into separate groups
    private _arm_groups = [];
    {
        private _driver = driver _x;
        private _arm_grp = createGroup side _driver;
        private _arm_crew = [];
        {
            if (group _x == group _driver) then { _arm_crew pushBack _x; };
        } forEach crew _x;
        _arm_crew joinSilent _arm_grp;
        _arm_grp setBehaviour "Combat";
        _arm_grp setCombatMode "RED";
        _arm_groups pushBack _arm_grp;
        _x move (getPos _x);
        _x limitspeed 10000;
        diag_log format ["[ConvoyMove %1] %2 crew group created", _ConvoyID, _x];
    } forEach _arm_vehicles;

    // {
    //     _x setBehaviour "Combat";
    // } forEach _arm_groups;

    // Dismount inf
    for "_i" from 0 to (count _convoyArray) - 1 step 1 do
    {
        _vcl 	= _convoyArray select _i;
        _crew 	= crew _vcl;
        if (alive _vcl && !(_vcl in _arm_vehicles)) then 
        {
            while {speed _vcl > 2} do {sleep 0.5};
            for "_c" from 0 to (count _crew) - 1 step 1 do 
            {
                _unit = _crew select _c;
                if ((group _unit) in _inf_groups) then 
                { 
                    _unit action ["GetOut", _vcl];
                    [_unit] allowGetIn false;
                };
            };
        };
    };

    // Inf to combat mode
    {
        _x setBehaviour "Combat";
        _x setCombatMode "RED";
    } forEach _inf_groups;

    sleep 5; // Wait for infantry to get out
    [_markersRemaining, _aliveConvoy, _all_groups, _arm_groups, _ConvoySpeedLimit, _ConvoySearchRange, _ConvoyID, _ConvoySpeedMode, _ConvoyBehaviour, _arm_vehicles] spawn DEVAS_ConvoyAmbush;
};