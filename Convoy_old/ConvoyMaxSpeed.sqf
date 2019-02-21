// ConvoyMaxSpeed.sqf 
// � v.2.5 MARCH 2016 - Devastator_cm

private _vcl 				= _this select 0;
private _last_marker 		= _this select 1;
private _convoyArray		= _this select 2;
private _c 					= _this select 3;
private _ConvoySearchRange	= _this select 4;
private _vcl_behind 		= objNull;
private _vcl_ahead 			= objNull;
private _destinationEnd 	= getMarkerPos _last_marker;
private _unit 				= objNull;
private _enemySides			= objNull;
private _enemies 			= [];
private _enemySides 		= (driver _vcl) call BIS_fnc_enemySides;

//private SPEED_SCALE = 1; // default 2

// private _getConvoyCurrentMarker2D = {
// 	params ["_vehicle"];
// 	[getmarkerpos(_vehicle getVariable "DEVAS_ConvoyCurrentMarker") select 0, getmarkerpos(_vehicle getVariable "DEVAS_ConvoyCurrentMarker") select 1, 0]
// };

if (isPlayer (driver _vcl)) exitWith {};

if (_c < (count _convoyArray) -1) then {_vcl_behind = _convoyArray select (_c + 1)};
if (_c > 0) then {_vcl_ahead = _convoyArray select (_c - 1)};

[_vcl, "ConvoyMaxSpeedAhead", 0.1, -3, 3, 0.01, 0, 0] call PID_fnc_Init;
[_vcl, "ConvoyMaxSpeedBehind", 0.1, -2, 2, 0.01, 0, 0] call PID_fnc_Init;
[_vcl, "ConvoyMaxSpeedAdjust", 0.1, 0, 1, -0.02, -0.002, 0] call PID_fnc_Init;

private _setdist_ahead = if (!isNull _vcl_ahead) then { _vcl distance _vcl_ahead } else { 0 };
private _setdist_behind = if (!isNull _vcl_behind) then { _vcl distance _vcl_behind } else { 0 };

if (!isNull _vcl_ahead) then { _vcl setConvoySeparation _setdist_ahead; };

while {alive _vcl && !(_vcl getVariable "DEVAS_ConvoyAmbush")} do {

	if (_vcl distance _destinationEnd < 10 * (_c + 1) && 
		_vcl getVariable "DEVAS_ConvoyCurrentMarker" == _last_marker) then {
		_vcl setVariable ["DEVAS_ConvoyDestination",true, false];
	};

	_aliveConvoy	= [];
	
	{
		_unit 	 	= _x;
		_enemies 	= (_unit neartargets _ConvoySearchRange) apply {_x select 4} select {side _x in _enemySides AND {count crew _x > 0} AND typeOf _x != "Logic" AND !(_x isKindOf "Air")};
		if (canMove _x && _enemies isEqualTo []) then {_aliveConvoy pushBack _x;};
	} forEach _convoyArray;

	if (count _aliveConvoy < count _convoyArray) exitWith {_vcl setVariable ["DEVAS_ConvoyAmbush",true, false]};

	// if (!isNull _vcl_ahead) then {

	// 	private _accel = [_vcl, "ConvoyMaxSpeedAhead", 15, _vcl distance _vcl_ahead] call PID_fnc_Calculate;

	// 	_dir = getDir _vcl;
	// 	_vcl setVelocity [
	// 		(velocity _vcl select 0) - (_accel * (sin _dir)), 
	// 		(velocity _vcl select 1) - (_accel * (cos _dir)), 
	// 		velocity _vcl select 2];
	// };
	if (!isNull _vcl_behind) then {
		private _dist_off = (_vcl distance _vcl_behind) - _setdist_behind;
		//private _speed_limit = (-5 max (39 min (_dist_off * _dist_off / 50))); //([_vcl, "ConvoyMaxSpeedAdjust", 0, _dist_off] call PID_fnc_Calculate);
		private _speed_limit = ([_vcl, "ConvoyMaxSpeedAdjust", 0, _dist_off] call PID_fnc_Calculate);

		diag_log format ["[ConvoyMaxSpeed %1] capping speed to %2, dist off %3, set dist %4", _vcl, _speed_limit, _dist_off, _setdist_behind];
		_vcl limitSpeed 40 - (39 * _speed_limit);

		//private _vel = velocityModelSpace _vcl; 


		//_vcl setVelocityModelSpace [_vel select 0, (_vel select 1) * (1 - _accel), _vel select 2];

		// _dir = getDir _vcl;
		// _vcl setVelocity [
		// 	(velocity _vcl select 0) + (_accel * (sin _dir)), 
		// 	(velocity _vcl select 1) + (_accel * (cos _dir)), 
		// 	velocity _vcl select 2];
	};
	// if (!isNull _vcl_ahead) then {

	// 	private _accel = [_vcl, "ConvoyMaxSpeedAhead", _setdist_ahead, _vcl distance _vcl_ahead] call PID_fnc_Calculate;

	// 	private _vel = velocityModelSpace _vcl; 

	// 	_vcl setVelocityModelSpace [_vel select 0, (_vel select 1) * (1 - _accel), _vel select 2];

	// 	// _dir = getDir _vcl;
	// 	// _vcl setVelocity [
	// 	// 	(velocity _vcl select 0) + (_accel * (sin _dir)), 
	// 	// 	(velocity _vcl select 1) + (_accel * (cos _dir)), 
	// 	// 	velocity _vcl select 2];
	// };

	// if (!isNull _vcl_ahead) then {

	// 	private _accel = [_vcl, "ConvoyMaxSpeed", 15, _vcl distance _vcl_ahead] call PID_fnc_Calculate;

	// 	_dir = getDir _vcl;
	// 	_vcl setVelocity [
	// 		(velocity _vcl select 0) - (_accel * (sin _dir)), 
	// 		(velocity _vcl select 1) - (_accel * (cos _dir)), 
	// 		velocity _vcl select 2];
	// 	// _vcl setVelocity [
	// 	// 	(_speed * (sin _dir)), 
	// 	// 	(_speed * (cos _dir)), 
	// 	// 	velocity _vcl select 2];
		
	// 	// while {
	// 	// 		_vcl distance _vcl_behind > 40 
	// 	// 		//&& _vcl distance ([_vcl] call _getConvoyCurrentMarker2D)
	// 	// 		//[getmarkerpos(_vcl getVariable "DEVAS_ConvoyCurrentMarker") select 0,
	// 	// 		//getmarkerpos(_vcl getVariable "DEVAS_ConvoyCurrentMarker") select 1, 0] 
	// 	// 		//< _vcl_behind distance ([_vcl] call _getConvoyCurrentMarker2D)
	// 	// 		//[getmarkerpos(_vcl getVariable "DEVAS_ConvoyCurrentMarker") select 0, 
	// 	// 		//getmarkerpos(_vcl getVariable "DEVAS_ConvoyCurrentMarker") select 1, 0]
	// 	// 		} do {	
	// 	// 	if (_vcl distance _vcl_behind <= 100) then {
	// 	// 		if (((sin _dir) * (velocity _vcl select 0)) > 3) then {
	// 	// 			_vcl setVelocity [(velocity _vcl select 0) - (1 * SPEED_SCALE * (sin _dir)), (velocity _vcl select 1), velocity _vcl select 2];
	// 	// 		};
	// 	// 		if (((cos _dir) * (velocity _vcl select 1)) > 3) then {
	// 	// 			_vcl setVelocity [(velocity _vcl select 0), (velocity _vcl select 1) - (1 * SPEED_SCALE * (cos _dir)), velocity _vcl select 2];
	// 	// 		};
	// 	// 	} else {
	// 	// 		if (((sin _dir) * (velocity _vcl select 0)) > 1) then {
	// 	// 			_vcl setVelocity [(velocity _vcl select 0) - (2 * SPEED_SCALE * (sin _dir)), (velocity _vcl select 1), velocity _vcl select 2];
	// 	// 		};
	// 	// 		if (((cos _dir) * (velocity _vcl select 1)) > 1) then {
	// 	// 			_vcl setVelocity [(velocity _vcl select 0), (velocity _vcl select 1) - (2 * SPEED_SCALE * (cos _dir)), velocity _vcl select 2];
	// 	// 		};
	// 	// 	};

	// 	// 	sleep 0.1;
	// 	// };
	// };
	// // if (!isNull _vcl_ahead) then {
	// // 	while { 
	// // 			_vcl distance _vcl_ahead < 20
	// // 			//|| _vcl distance ([_vcl] call _getConvoyCurrentMarker2D)
	// // 			//[getmarkerpos(_vcl getVariable "DEVAS_ConvoyCurrentMarker") select 0, 
	// // 			//getmarkerpos(_vcl getVariable "DEVAS_ConvoyCurrentMarker") select 1, 0] 
	// // 			//< _vcl_ahead distance ([_vcl] call _getConvoyCurrentMarker2D)
	// // 			//[getmarkerpos(_vcl getVariable "DEVAS_ConvoyCurrentMarker") select 0, 
	// // 			//getmarkerpos(_vcl getVariable "DEVAS_ConvoyCurrentMarker") select 1, 0]
	// // 			} do {	
	// // 		_dir = getDir _vcl;
	// // 		if (((sin _dir) * (velocity _vcl select 0)) > 1) then {
	// // 			_vcl setVelocity [(velocity _vcl select 0) - (2 * SPEED_SCALE * (sin _dir)), (velocity _vcl select 1), velocity _vcl select 2];
	// // 		};
	// // 		if (((cos _dir) * (velocity _vcl select 1)) > 1) then {
	// // 			_vcl setVelocity [(velocity _vcl select 0), (velocity _vcl select 1) - (2 * SPEED_SCALE * (cos _dir)), velocity _vcl select 2];
	// // 		};
	// // 		sleep 0.1;
	// // 	};
	// // };
	sleep 0.1;
};
//_vcl doMove getPos _vcl;