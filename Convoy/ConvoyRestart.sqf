// ConvoyRestart.sqf
// © v.2.5 MARCH 2016 - Devastator_cm

private _markerArray  		= _this select 0;
private _convoyArray  		= _this select 1;
private _groups		  		= _this select 2; //all groups
private _inf_units			= _this select 3; //all units 
private _ConvoySpeedLimit	= _this select 4;
private _ConvoySearchRange	= _this select 5;
private _ConvoyID			= _this select 6;
private _ConvoySpeedMode	= _this select 7;
private _ConvoyBehaviour	= _this select 8;
private _arm_vehicles		= _this select 9;
private _units_outside		= [];
private _vehicle			= objNull;
private _counter			= 0;
private _last_wp			= _markerArray select ((count _markerArray) - 1);
private _wp 				= objNull;
private _walking_dead		= objNull;
private _side 				= side (_groups select 0);
private _dummyGroup			= objNull;
private _loop				= 0;
private _walker				= objNull;
private _allWalkers			= [];
private _LoopStop			= false;
private _WaitLimit			= 60;  // Multiplier with 4 seconds
private _i 					= 0;
private _enemySides 		= leader (_groups select 0) call BIS_fnc_enemySides;
private _Ambush 			= false;
private _arm_groups         = [];
private _crew 				= [];
private _unit 				= objNull;
private _TempConvoy 		= [];

scopeName "main";

if (!_Ambush) then
{
    diag_log format ["[ConvoyRestart %1] Restarting convoy after ambush", _ConvoyID];

    diag_log format ["[ConvoyRestart %1] Clearing all waypoints, reseting movement", _ConvoyID];

    {
        while {(count (waypoints _x)) > 0} do {	deleteWaypoint ((waypoints  _x) select 0);};
        _x setBehaviour "SAFE";
        {_x doMove (getpos _x);} foreach units _x;
    } foreach _groups;
    
    { 
        if (!canmove _x) then
        {
            diag_log format ["[ConvoyRestart %1] Vehicle %2 cannot move, ejecting crew", _ConvoyID, _x];
            _vehicle = _x;
            {
                unassignVehicle (_x select 0);
                (_x select 0) action ["GetOut", _vehicle];
            } foreach fullcrew[_x, "", true];
        } else {
            if(_x in _arm_vehicles) then 
            {
                diag_log format ["[ConvoyRestart %1] Re-forming armored vehicle %2", _ConvoyID, _x];
                _pos     = _x getVariable "DEVAS_ConvoyVclPos";
                _wp     = group (driver _x) addWaypoint [_pos, 0];
                _wp     setWaypointCompletionRadius 10;
                _wp     setWaypointType           "MOVE";
                // Following lines are for debug. It is to see to which position vehicle will move
                //vclPosMrkr = createMarkerLocal [format ["getback%1", _x], _pos];
                //vclPosMrkr setMarkerTextLocal format["getback%1", _x];
                //_vclPosMrkr setMarkerTypeLocal "hd_end";
            };
        };
    } foreach _convoyArray;

    private _timeout = time + 20;

    diag_log format ["[ConvoyRestart %1] Waiting for reforming of vehicles", _ConvoyID];

    // Wait for waypoints
    while {
        count (_convoyArray select { _x distance (_x getVariable "DEVAS_ConvoyVclPos") > 10 }) > 0
        //!({ 
        //    if ((_x distance (_x getVariable "DEVAS_ConvoyVclPos")) > 10) then { true }; exitWith { false } } foreach _convoyArray)
        && time < _timeout
    } do {
        if ([_enemySides, _inf_units] call DEVAS_ConvoySearch) exitwith {
            diag_log format ["[ConvoyRestart %1] Ambush detected while waiting for re-form", _ConvoyID];
            _Ambush = true; breakTo "main";
        };
        sleep 1;
    };

    diag_log format ["[ConvoyRestart %1] Fixing up re-form", _ConvoyID];

    { 
        private _origPos = _x getVariable "DEVAS_ConvoyVclPos";
        if ((_x distance _origPos) > 10) then {
            private _placementPos = _origPos findEmptyPosition [0, 50, typeOf _x];
            diag_log format ["[ConvoyRestart %1] Repositioning %2, %3 m from original location", _ConvoyID, _x, (_origPos distance _placementPos)];

            _x setPos _placementPos;
            _x setDir (_x getVariable "DEVAS_ConvoyVclDir");
        }; 
    } foreach _convoyArray;

    diag_log format ["[ConvoyRestart %1] Letting inf back into vehicles", _ConvoyID];
    {[_x] allowGetIn true;}	foreach _inf_units;

    diag_log format ["[ConvoyRestart %1] Ordering inf back into vehicles", _ConvoyID];

    // OUTSIDER CREATION
    {
        _vehicle = assignedVehicle _x;
        _units_outside pushBack _x;
        if(_vehicle in _arm_vehicles) then
        {
            diag_log format ["[ConvoyRestart %1] %2 ordered to get back into %3", _ConvoyID, _x, _vehicle];
            _wp = group _x addWaypoint [getpos _vehicle, 0];
            _wp waypointAttachVehicle 	_vehicle;
            _wp setWaypointType 		"GETIN";
        };
    }	foreach (_inf_units select {isNull objectParent _x});

    if ([_enemySides, _inf_units] call DEVAS_ConvoySearch) exitwith {
        diag_log format ["[ConvoyRestart %1] Ambush detected while waiting for inf to remount", _ConvoyID];
        _Ambush = true; breakTo "main";
    };

    //GUNNER DRIVER CHECK
    {
        _vehicle = _x;
        if(isnull (assignedDriver _vehicle) || !alive (assignedDriver _vehicle)) then
        {  
            diag_log format ["[ConvoyRestart %1] %2 driver is missing or dead", _ConvoyID, _vehicle];
            {
                if((assignedVehicleRole _x) select 0 == "Cargo") exitwith
                {
                    diag_log format ["[ConvoyRestart %1] Assigning %2 as driver of %3", _ConvoyID, _x, _vehicle];
                    if(!(isNull objectParent _x)) then {_x action ["GetOut", vehicle _x];};				
                    _dummyGroup		= createGroup _side;
                    [_x] joinSilent _dummyGroup;
                    _x assignAsDriver _vehicle;
                    _units_outside pushBack _x;
                    _wp = _dummyGroup addWaypoint [getpos _vehicle, 0];
                    _wp waypointAttachVehicle 	_vehicle;
                    _wp setWaypointType 	  	"GETIN";
                };
            } foreach _inf_units;
        };
        if((isnull (assignedGunner _vehicle) || !alive (assignedGunner _vehicle)) && _vehicle in _arm_vehicles) then
        {  
            diag_log format ["[ConvoyRestart %1] %2 gunner is missing or dead", _ConvoyID, _vehicle];
            {
                if((assignedVehicleRole _x) select 0 == "Cargo") exitwith
                {
                    diag_log format ["[ConvoyRestart %1] Assigning %2 as gunner of %3", _ConvoyID, _x, _vehicle];
                    if(!(isNull objectParent _x)) then {_x action ["GetOut", vehicle _x];};
                    _dummyGroup		= createGroup _side;
                    [_x] joinSilent _dummyGroup;
                    _x assignAsGunner _vehicle;
                    _units_outside pushBack _x;
                    _wp =_dummyGroup addWaypoint [getpos _vehicle, 0];
                    _wp waypointAttachVehicle 	_vehicle;
                    _wp setWaypointType 	  	"GETIN";
                };
            } foreach _inf_units;
        };
    } foreach (_convoyArray select {canmove _x});

    diag_log format ["[ConvoyRestart %1] Waiting 30 sec", _ConvoyID];
    for "i" from 1 to 30 step 1 do
    { 
        if ([_enemySides, _inf_units] call DEVAS_ConvoySearch) exitwith {
            diag_log format ["[ConvoyRestart %1] Ambush detected while waiting 30 sec", _ConvoyID];
            _Ambush = true; breakTo "main";
        };
        sleep 1;
    };

    diag_log format ["[ConvoyRestart %1] Waiting for all units to get mounted", _ConvoyID];
    _counter = 0;
    _LoopStop = false;
    while {!_LoopStop && !(_units_outside isEqualTo [])} do
    {
        if (_counter == _WaitLimit) then {
            diag_log format ["[ConvoyRestart %1] Timed out waiting for all units to get mounted", _ConvoyID];
            _LoopStop = true;
        };
        if({isNull objectParent _x} count _units_outside == 0) exitwith {};
        _counter = _counter + 1;
        sleep 1;
        if ([_enemySides, _inf_units] call DEVAS_ConvoySearch) exitwith {
            diag_log format ["[ConvoyRestart %1] Ambush detected while waiting for all units to get mounted", _ConvoyID];
            _Ambush = true; breakTo "main";
        };
    };

    diag_log format ["[ConvoyRestart %1] Checking for walkers", _ConvoyID];

    //WALKERS CHECK
    _walking_dead 	= createGroup _side;
    {
        diag_log format ["[ConvoyRestart %1] %2 is a walker", _ConvoyID, _x];
        [_x] joinSilent (_walking_dead);
    } foreach (_inf_units select {isNull objectParent _x});
    _counter = 0;

    _units_outside = [];
    if(!((units _walking_dead) isEqualTo [])) then
    {
        _allWalkers = units _walking_dead;
        {  
            _counter = ({isnull (_x select 0)} count fullcrew[_x, "", true]) + ({!alive _x} count crew _x);
            if (_counter != 0 && canmove _x) then 
            {
                diag_log format ["[ConvoyRestart %1] Found spaces for %2 walkers in %3, assigning them", _ConvoyID, _counter, _x];
                _dummyGroup		= createGroup _side;
                for "i" from 1 to _counter step 1 do
                { 
                    _walker = _allWalkers select 0;
                    if(!isnull _walker) then
                    {
                        [_walker] joinSilent _dummyGroup;
                        _allWalkers 	= _allWalkers  - [_walker];
                        _units_outside 	pushBack _walker;			
                    };
                    if (_allWalkers isEqualTo []) exitwith {};
                };
                _wp = _dummyGroup addWaypoint [getpos _x, 0];
                _wp waypointAttachVehicle _x;
                _wp setWaypointType 		"GETIN";
            };
            if (_allWalkers isEqualTo []) exitwith {};
        }	foreach (_convoyArray - (_arm_vehicles - (_arm_vehicles -_convoyArray)) + (_arm_vehicles - (_arm_vehicles -_convoyArray))); // non armored vehicles are high prio to find seat
    };

    diag_log format ["[ConvoyRestart %1] Waiting for walkers to mount up", _ConvoyID];
    _counter = 0;
    _LoopStop = false;
    while {!_LoopStop  && !(_units_outside isEqualTo [])} do
    {
        if (_counter == _WaitLimit) then {
            diag_log format ["[ConvoyRestart %1] Timed out waiting for walkers to get mounted", _ConvoyID];
            _LoopStop = true;
        };
        if({isNull objectParent _x} count _units_outside == 0) exitwith {};
        _counter = _counter + 1;
        sleep 1;
        if ([_enemySides, _inf_units] call DEVAS_ConvoySearch) exitwith {
            diag_log format ["[ConvoyRestart %1] Ambush detected while waiting for walkers to get mounted", _ConvoyID];
            _Ambush = true;breakTo "main";
        };
    };

    // 2nd GUNNER DRIVER CHECK
    _units_outside = [];  // Second time gunner and driver check just in case
    {
        _vehicle = _x;
        if(isnull (assignedDriver _vehicle) || !alive (assignedDriver _vehicle)) then
        {
            {
                if((assignedVehicleRole _x) select 0 == "Cargo") exitwith
                {
                    diag_log format ["[ConvoyRestart %1] Assigning %2 as driver of %3", _ConvoyID, _x, _vehicle];

                    if(!(isNull objectParent _x)) then {_x action ["GetOut", vehicle _x];};				
                    _dummyGroup		= createGroup _side;
                    [_x] joinSilent _dummyGroup;
                    _x assignAsDriver _vehicle;
                    _units_outside pushBack _x;
                    _wp = _dummyGroup addWaypoint [getpos _vehicle, 0];
                    _wp waypointAttachVehicle 	_vehicle;
                    _wp setWaypointType 	  	"GETIN";
                };
            } foreach _inf_units;
        };
        if((isnull (assignedGunner _vehicle) || !alive (assignedGunner _vehicle)) && _vehicle in _arm_vehicles) then
        {  
            {
                if((assignedVehicleRole _x) select 0 == "Cargo") exitwith
                {
                    diag_log format ["[ConvoyRestart %1] Assigning %2 as gunner of %3", _ConvoyID, _x, _vehicle];

                    if(!(isNull objectParent _x)) then {_x action ["GetOut", vehicle _x];};
                    _dummyGroup		= createGroup _side;
                    [_x] joinSilent _dummyGroup;
                    _x assignAsGunner _vehicle;
                    _units_outside pushBack _x;
                    _wp =_dummyGroup addWaypoint [getpos _vehicle, 0];
                    _wp waypointAttachVehicle 	_vehicle;
                    _wp setWaypointType 	  	"GETIN";
                };
            } foreach _inf_units;
        };
    } foreach (_convoyArray select {canmove _x});

    diag_log format ["[ConvoyRestart %1] Waiting for walkers to mount up again", _ConvoyID];
    _counter = 0;
    _LoopStop = false;
    while {!_LoopStop && !(_units_outside isEqualTo [])} do
    {
        if (_counter == _WaitLimit) then {
            diag_log format ["[ConvoyRestart %1] Timed out waiting for walkers to get mounted again", _ConvoyID];
            _LoopStop = true;
        };
        if({isNull objectParent _x} count _units_outside == 0) exitwith {};
        _counter = _counter + 1;
        sleep 1;
        if ([_enemySides, _inf_units] call DEVAS_ConvoySearch) exitwith {_Ambush = true;breakTo "main"};
    };

    deleteGroup _walking_dead;
    _walking_dead 	= createGroup _side;
    {
        [_x] join (_walking_dead);
    } 	foreach (_inf_units select {isNull objectParent _x});

    if(!((units _walking_dead) isEqualTo [])) then 
    {
        diag_log format ["[ConvoyRestart %1] Sending %2 walkers on their way", _ConvoyID, count _walking_dead];
        _wp =_walking_dead addWaypoint [getMarkerPos _last_wp, 20];
        _wp setWaypointBehaviour 	"SAFE";
        _wp setWaypointCombatMode 	"YELLOW";
        _wp setWaypointType 		"MOVE";
        _wp setWaypointFormation 	"COLUMN";
        _wp setWaypointSpeed 		"LIMITED";
        {if(rankId _x > rankId (leader _walking_dead)) then {_walking_dead selectLeader _x;};} foreach units _walking_dead;
    } else {
        deleteGroup _walking_dead
    };

    if ([_enemySides, _inf_units] call DEVAS_ConvoySearch) exitwith {
        diag_log format ["[ConvoyRestart %1] Ambush detected", _ConvoyID];
        _Ambush = true;breakTo "main";
    };

    {
        diag_log format ["[ConvoyRestart %1] Removing vehicle %2 from the convoy, it can't continue", _ConvoyID, _x];
        _convoyArray = _convoyArray - [_x];
    } foreach (_convoyArray select {isnull(driver _x) || !alive(driver _x)|| !alive _x || !canmove _x || side _x != _side});

    diag_log format ["[ConvoyRestart %1] Waiting for a bit", _ConvoyID];
    while {_counter > 0} do
    {
        _counter = _counter - 1;
        sleep 1;
        if ([_enemySides, _inf_units] call DEVAS_ConvoySearch) exitwith {
            diag_log format ["[ConvoyRestart %1] Ambush detected", _ConvoyID];
            _Ambush = true;breakTo "main";
        };
    };

    if (count _convoyArray > 0) then {
        diag_log format ["[ConvoyRestart %1] Spawning ConvoyMove", _ConvoyID];
        [_markerArray, _convoyArray, _ConvoySpeedLimit, _ConvoySearchRange, _ConvoyID, _ConvoySpeedMode, _ConvoyBehaviour] spawn DEVAS_ConvoyMove;
    };
};

if (_Ambush) then 
{
    diag_log format ["[ConvoyRestart %1] Preparing to enter ambush response", _ConvoyID];

    {_convoyArray 	= _convoyArray  - [_x];} foreach (_convoyArray select { !alive _x || !canmove _x});
    {_arm_vehicles 	= _arm_vehicles - [_x];} foreach (_arm_vehicles select { !alive _x || !canmove _x});
    {
        _arm_groups pushBack (group driver _x);
        _x doMove (getPos _x)
    }	foreach _arm_vehicles;


    {_x setBehaviour "Combat";} forEach _arm_groups;
    _groups = [];
    {_groups pushBackUnique group _x} foreach (_inf_units select {alive _x}); 
    _inf_groups = _groups - _arm_groups;

    for "_i" from 0 to (count _convoyArray) - 1 step 1 do
    {
        _vehicle 	= _convoyArray select _i;
        _crew 		= crew _vehicle;
        if (alive _vehicle && !(_vehicle in _arm_vehicles)) then 
        {
            while {speed _vehicle > 2} do {sleep 0.5};
            for "_counter" from 0 to (count _crew) - 1 step 1 do 
            {
                _unit = _crew select _counter;
                if ((group _unit) in _inf_groups) then 
                { 
                    _unit action ["GetOut", _vehicle];
                    [_unit] allowGetIn false;
                };
            };
        };
    };
    {
        _x setBehaviour "Combat";
         _x setCombatMode "RED";
    } 	forEach _inf_groups;
    sleep 5; // Wait for infantry to get out
    [_markerArray, _convoyArray, _groups, _arm_groups, _ConvoySpeedLimit, _ConvoySearchRange, _ConvoyID, _ConvoySpeedMode, _ConvoyBehaviour, _arm_vehicles] spawn DEVAS_ConvoyAmbush;
};