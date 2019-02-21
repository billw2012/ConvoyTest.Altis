params [
	['_groupOrVehicles', objNull],
	['_interval', 10],
	['_strength', 10]
];

// [array of vehicles] execVM "vehicleNudge.sqf";
// [group] execVM "vehicleNudge.sqf";


private _vehicles = [];

switch(typeName _groupOrVehicles) do {
	case "ARRAY": {
		_vehicles = _groupOrVehicles;
	};
	case "GROUP": {
		{ _vehicles pushBackUnique (vehicle _x) } forEach units _groupOrVehicles;
	};
};

{
	diag_log format ["[vehicleNudge] starting for %1", _x];

	[_x, _interval, _strength] spawn
	{	// spawned code to try to unstick stuck vehicles
		params ["_vq", "_interval", "_strength"];
		while {(alive (driver _vq))} do
		{
			private _q = driver _vq;
			private _pvq = getpos _vq;
			private _psq = getPosASL _vq;

			sleep _interval;

			if ((_vq getVariable "vehicleNudge") and (abs(speed _vq) < 1) and { (alive _q) and (canMove _vq) and ((fuel _vq) > 0) and ((_vq distance2D _pvq) < 8) }) then {
				private _pushdir = 0;
				// vehicle is stuck
				if ((lineintersectssurfaces [_vq modeltoworldworld [0,0,0.2], _vq modeltoworldworld [0,8,0.2], _vq]) isEqualTo []) then {
					//push it forwards a little
					_pushdir = _strength;
				} else {
					// if there's something in front, push backwards, not forwards
					_pushdir = -_strength;
				};
				_vq setVelocityModelSpace [0,_pushdir,0];
				diag_log format ["*** pushing %1 a little", name _q];
			};
		};
	};
} foreach _vehicles;