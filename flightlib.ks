///////////////////////////////////////////////////////////////////////////
// Function activateantenna included from activateantenna.ks
///////////////////////////////////////////////////////////////////////////

function activateantenna {
	FOR P IN SHIP:PARTS {
		IF P:MODULES:CONTAINS("ModuleRTAntenna") {
			LOCAL M IS P:GETMODULE("ModuleRTAntenna").
			FOR A IN M:ALLEVENTNAMES() {
				IF A:CONTAINS("Activate") { M:DOEVENT("Activate"). }
				IF M:HASFIELD("target") {M:SETFIELD("target", "Mission Control").}
			}
		}
	}
}

///////////////////////////////////////////////////////////////////////////
// Function checkstage included from checkstage.ks
///////////////////////////////////////////////////////////////////////////

function checkstage {
	if stage:number > 0 {
	if maxthrust = 0 {
		stage.
	}
	SET numOut to 0.
	LIST ENGINES IN engines. 
	FOR eng IN engines {
	  IF eng:IGNITION and eng:FLAMEOUT {
		SET numOut TO numOut + 1.
	  }
	}
	if numOut > 0 { stage. wait .5. }.
	}
}

///////////////////////////////////////////////////////////////////////////
// Function circularize included from circularize.ks
///////////////////////////////////////////////////////////////////////////

function circularize {
	if obt:transition = "ESCAPE" or eta:periapsis < eta:apoapsis {
		HUDTEXT("Burning at periapsis", 4, 2, 30, yellow, false).
		node_apsis(obt:periapsis, "periapsis").
	} else {
		HUDTEXT("Burning at apoapsis", 4, 2, 30, yellow, false).
		node_apsis(obt:apoapsis, "apoapsis").
	}
	
	execnode().
}

///////////////////////////////////////////////////////////////////////////
// Function deactivateantenna included from deactivateantenna.ks
///////////////////////////////////////////////////////////////////////////

function deactivateantenna {
			FOR P IN SHIP:PARTS {
				IF P:MODULES:CONTAINS("ModuleRTAntenna") {
					LOCAL M IS P:GETMODULE("ModuleRTAntenna").
					FOR A IN M:ALLEVENTNAMES() {
						IF A:CONTAINS("Deactivate") { M:DOEVENT("Deactivate"). }
						IF M:HASFIELD("target") {M:SETFIELD("target", "Mission Control").}
					}.
				}
			}.
}

///////////////////////////////////////////////////////////////////////////
// Function execnode included from execnode.ks
///////////////////////////////////////////////////////////////////////////

function execnode {
	
	parameter nn is nextnode.
	
	lock steering to lookdirup(nn:deltav, ship:facing:topvector). //points to node, keeping roll the same.
	
	local burn_stats is half_dv_duration(nn:deltav:mag).
	local first_half_duration is burn_stats[0].
	local burnDuration is first_half_duration + burn_stats[1].
	
	set kuniverse:timewarp:warp to 0.
	
	set node_time to time:seconds + nn:eta.
	set warp_target to node_time - 15 - first_half_duration.
	
	wait until vang(facing:vector, steering:vector) < 1 or time:seconds >= warp_target.
	
	HUDTEXT("Estimated burn duration: " + round(burnDuration,1) + "s", 15, 2, 20, yellow, false).
		
	if warp_target > time:seconds {
	   set kuniverse:timewarp:mode to "rails".
	   wait 0.
	   kuniverse:timewarp:warpto(warp_target).
	}
	lock steering to lookdirup(nn:deltav, ship:facing:topvector). //points to 
	wait until vang(facing:vector, steering:vector) < 1. 
	
	wait until nn:eta - first_half_duration <= 0. //wait until we are close to executing the node
	set kuniverse:timewarp:mode to "physics". //se we can manually physics warp during a burn
	
	HUDTEXT("Begin burn. Physics warp is possible.", 5, 2, 20, yellow, false).
	
	set dv0 to nn:deltav.
	
	local done is false.
	
	set th to 0.
	lock throttle to th.
	
	until done {
		checkstage().	  
		set max_acc to ship:availablethrust/ship:mass.
		if max_acc > 0 {
			if nn:deltav:mag/(max_acc*10) < 1 set warp to 0. //warp
		}
		if vang(facing:vector, steering:vector) > 1 { set th to 0. }
		else {
			if max_acc > 0 {
				set th to min(nn:deltav:mag/(max_acc*1.2), 1). 
			}
		}
		
		if nn:deltav:mag < 0.05 set done to true.
		wait 0.
	}
	
	HUDTEXT("Manouver node has been executed!", 4, 2, 30, yellow, false).
	
	set kuniverse:timewarp:mode to "rails".
	unlock steering.
	set th to 0.
	unlock throttle.
	set ship:control:pilotmainthrottle to 0.
	remove nn.
}

///////////////////////////////////////////////////////////////////////////
// Function gravityturn included from gravityturn.ks
///////////////////////////////////////////////////////////////////////////

function gravityturn {
	
	parameter direction is 90.
	parameter apTarget is 90000.
	
	clearscreen.
	
	local th is 0.
	
	lock distance to body:radius + ship:altitude.
	lock weight to ship:mass * body:mu / (distance)^2.
	
	lock steering to mysteer.
	lock throttle to th.
	until (ship:altitude > body:atm:height) and (ship:apoapsis > apTarget) {
	if ship:apoapsis < apTarget {
		set inclination to max( 5, 90 * (1 - ALT:RADAR / 50000)).
		set mysteer to lookdirup(heading(direction, inclination):vector, ship:facing:topvector).
		
		checkstage().
		if ship:availablethrust > 0 {
			set th to min(1, ship:mass * 2.5 * body:mu / (distance)^2 / ship:availablethrust).
		}
	} else {
		set th to 0.
	}
	print "Apoapsis: " + round(ship:apoapsis, 0) at (0, 3).
	}
	unlock throttle.
}

///////////////////////////////////////////////////////////////////////////
// Function hohtransfer included from hohtransfer.ks
///////////////////////////////////////////////////////////////////////////

function hohtransfer {
	parameter transfertarget is target.
	
	if ship:body <> transfertarget:body {
		HUDTEXT("Target outside of SoI", 4, 2, 30, yellow, false).
	} else {
		local ri is abs(obt:inclination - transfertarget:obt:inclination).
		
		if ri > 0.25 {
			HUDTEXT("Aligning planes with" + transfertarget:name, 4, 2, 30, yellow, false).
			node_inc_tgt().
			execnode().
		}
		
		node_hoh().
		HUDTEXT("Transfer injection burn", 4, 2, 30, yellow, false).
		execnode().
		local warpset is false.
		until obt:transition <> "ENCOUNTER" {
			if kuniverse:timewarp:rate > 1 {
				set warpset to false.
			}
			if not warpset {
				HUDTEXT("Warping to Encounter with" + transfertarget:name, 4, 2, 30, yellow, false).
				set kuniverse:timewarp:mode to "rails".
				wait 0.
				kuniverse:timewarp:warpto(time:seconds + eta:transition + 1).
				wait 10.
				wait until kuniverse:timewarp:warp = 0 and kuniverse:timewarp:ISSETTLED.
				set warpset to true.
			}
		}
		HUDTEXT("Encounter...", 4, 2, 30, yellow, false).
		
		local minperi is (body:atm:height + (body:radius * 0.3)).
		
		if ship:periapsis < minperi or ship:obt:inclination > 90 {
			LOCK STEERING TO heading(90, 0).
			wait 10.
			LOCK deltaPct to (ship:periapsis - minperi) / minperi.
			LOCK throttle to max(1, min(0.1,deltaPct)).
			wait until ship:periapsis > minperi.
			LOCK throttle to 0.
			unlock throttle.
			unlock steering.
		}
		HUDTEXT("Transfer braking burn", 4, 2, 30, yellow, false).
		circularize().
	}
}

///////////////////////////////////////////////////////////////////////////
// Function land included from land.ks
///////////////////////////////////////////////////////////////////////////

function land {
	// Get into suitable orbit
	local th is 0.
	local height is body:radius * 0.1 + body:atm:height.
	
	if ship:altitude > height * 1.1 {
		print height.
		print height * 1.1.
		print ship:altitude.
		HUDTEXT("Setting altitude to " + height, 15, 2, 20, yellow, false).
		node_apsis(body:radius * 0.1, apoapsis).
		execnode().
		circularize().
	}
	
	// Face the right way
	HUDTEXT("Facing ship", 15, 2, 20, yellow, false).
	
	lock throttle to th.
	lock steering to ship:velocity:surface * -1.
	wait until vang(facing:vector, ship:velocity:surface * -1) < 1.
	
	// Kill surface velocity
	HUDTEXT("Decelerating", 15, 2, 20, yellow, false).
	
	until ship:groundspeed < 10 {
		if ship:groundspeed > 200 {
			set th to 1.
		}
		if ship:groundspeed > 100 {
			set th to 0.75.
		}
		if ship:groundspeed > 50 {
			set th to 0.5.
		}
		checkstage().
	}
	
	wait 0.5.
	set th to 0.
	
	// Decend gently
	HUDTEXT("Landing", 15, 2, 20, yellow, false).
	
	lock radar to ship:altitude - ship:geoposition:terrainheight.
	local speed is ship:velocity:surface:mag.
	set th to 0.
	lock speed to max(0, 0.00003*radar^2 + 0.0687*radar + 2.217).
	
	// TODO: shutdown engines in current stage before separating, to keep them from
	// running out of control?
	
	until stage:number = 0 {
		stage.
		wait 3.
	}
	clearscreen.
	until radar < 5 {
		print radar at (0, 4).
		if radar < 20 { legs on.}
		print ship:velocity:surface:mag at (0, 5).
		print speed at (0, 6).
		if ship:velocity:surface:mag > speed {
			set th to min(1, th + 0.01).
		} else {
			set th to max(0, th - 0.1).
		}
	}
	set th to 0.
	sas on.
	unlock steering.
	unlock throttle.
	
}

///////////////////////////////////////////////////////////////////////////
// Function launch_countdown included from launch_countdown.ks
///////////////////////////////////////////////////////////////////////////

function launch_countdown {
	// Countdown and ignite first stage
	
	parameter countdownLength.
	
	clearscreen.
	print "Counting down: ".
	lock throttle to 1.
	from { local countdowntime is 10. } until countdowntime = 10 - countdownLength step { set countdowntime to countdowntime - 1.} do {
	print "T-MINUS " + countdowntime:tostring:padleft(2) + " seconds".
	wait 1.
	}
	if (countdownLength = 10) {
	print "Blastoff!".
	stage.
	wait 1.
	} else {
	print "T-MINUS ... um".
	stage.
	wait 1.
	wait 1.
	print "blastoff?".
	wait 1.
	}
}

///////////////////////////////////////////////////////////////////////////
// Function node_apsis included from node_apsis.ks
///////////////////////////////////////////////////////////////////////////

function node_apsis {
	// Add Node to change apsis opposite to burnApsis to altitude.
	
	parameter alt.
	parameter burnApsis.
	
	local apsis is 0.
	
	if burnApsis = "PERIAPSIS" {
		set apsis to periapsis.
	} else {
		set apsis to apoapsis.
	}
	
	local mu is body:mu.
	
	// present orbit properties
	local vom is ship:obt:velocity:orbit:mag.		// actual velocity
	local r is body:radius + ship:altitude.			// actual distance to body
	local ra is body:radius + apsis.			// radius at burn apsis
	local rb is 1 / (body:radius + ship:altitude).
	local rc is 2 / (body:radius + ship:altitude).
	local rab is 1 / ra.
	local v1 is sqrt( vom^2 + 2*mu*(rab - rb) ). 	// velocity at burn apsis
	
	// true story: if you name this "a" and call it from circ_alt, its value is 100,000 less than it should be!
	local sma1 is obt:semimajoraxis.
	
	// future orbit properties
	local r2 is body:radius + apsis.                    // distance after burn at burnApsis
	local sma2 is (alt + 2*body:radius + apsis)/2. 		// semi major axis target orbit
	local v2 is sqrt( vom^2 + (mu * (2/r2 - rc + 1/sma1 - 1/sma2 ) ) ).
	
	// create node
	local deltav is v2 - v1.
	
	if burnApsis = "PERIAPSIS" {
		local nd is node(time:seconds + eta:periapsis, 0, 0, deltav).
		add nd.
	} else {
		local nd is node(time:seconds + eta:apoapsis, 0, 0, deltav).
		add nd.
	}
}

///////////////////////////////////////////////////////////////////////////
// Function node_hoh included from node_hoh.ks
///////////////////////////////////////////////////////////////////////////

function node_hoh {
	parameter MaxOrbitsToTransfer is 5.
	parameter MinLeadTime is 30.
	
	
	function hohmannDv {
		local r1 is orbital_velocity(ship).
		local r2 is orbital_velocity(target).
	
		return orbital_dv(r1, r2).
	}
	
	function hohmannDt {
		local r1 is ship:obt:semimajoraxis.
		local r2 is target:obt:semimajoraxis.
		
		local pt is 0.5 * ((r1+r2) / (2*r2))^1.5.
		local ft is pt - floor(pt).
		
		local theta is 360 * ft.
		local phi is 180 - theta.
		
		set sAng to ship:obt:lan+obt:argumentofperiapsis+obt:trueanomaly.
		set tAng to target:obt:lan+target:obt:argumentofperiapsis+target:obt:trueanomaly.
		
		local timeToHoH is 0.
		
		local tAngSpd is 360 / target:obt:period.
		local sAngSpd is 360 / ship:obt:period.
		
		local phaseAngRoC is tAngSpd - sAngSpd.
		
		local HasAcceptableTransfer is false.
		local IsStranded is false.
		local tries is 0.
		
		until HasAcceptableTransfer or IsStranded {
			set pAng to reduce360(tAng - sAng).
			if r1 < r2 {
				set DeltaAng to reduce360(pAng - phi).
			} else {
				set DeltaAng to reduce360(phi - pAng).
			}
			set timeToHoH to abs(DeltaAng / phaseAngRoC).
			
			if timeToHoH > ship:obt:period * MaxOrbitsToTransfer { 
				set IsStranded to true.
			} else if timeToHoH > MinLeadTime {
				set HasAcceptableTransfer to true.
			} else {
				set tAng to tAng + MinLeadTime*tAngSpd.
				set sAng to sAng + MinLeadTime*sAngSpd.
			}
			set tries to tries + 1.
			if tries > 1000 {
				set IsStranded to true.
			}
			if IsStranded {break.}.
		}
		if IsStranded {
			return "Stranded".
		} else {
			return timeToHoH + time:seconds.
		}
	}
	
	global node_dv is hohmannDv().
	global node_t is hohmannDt().
	
	if node_t = "Stranded" {
		HUDTEXT("Stranded!", 4, 2, 30, yellow, false).
	} else {
		add node(node_t, 0, 0, node_dv).
		HUDTEXT("Transfer eta:" + round(node_t - time:seconds, 0), 4, 2, 30, yellow, false).
	}
}

///////////////////////////////////////////////////////////////////////////
// Function node_inc_tgt included from node_inc_tgt.ks
///////////////////////////////////////////////////////////////////////////

function node_inc_tgt {
	
	if hasnode remove nextnode. wait 0.
	
	local t0 is time:seconds.
	local ship_orbit_normal is vcrs(ship:velocity:orbit,positionat(ship,t0)-ship:body:position).
	local target_orbit_normal is vcrs(target:velocity:orbit,target:position-ship:body:position).
	local lineofnodes is vcrs(ship_orbit_normal,target_orbit_normal).
	local angle_to_node is vang(positionat(ship,t0)-ship:body:position,lineofnodes).
	local angle_to_node2 is vang(positionat(ship,t0+5)-ship:body:position,lineofnodes).
	local angle_to_opposite_node is vang(positionat(ship,t0)-ship:body:position,-1*lineofnodes).
	local relative_inclination is vang(ship_orbit_normal,target_orbit_normal).
	local angle_to_node_delta is angle_to_node2-angle_to_node.
	
	local ship_orbital_angular_vel is 360 / ship:obt:period.
	local time_to_node is angle_to_node / ship_orbital_angular_vel.
	local time_to_opposite_node is angle_to_opposite_node / ship_orbital_angular_vel.
	
	local t is 0.
	if angle_to_node_delta < 0 {
		set t to (time + time_to_node):seconds.
	} else {
		set t to (time + time_to_opposite_node):seconds.
	}
	
	local v is velocityat(ship, t):orbit.
	local vt is velocityat(target, t):orbit.
	local diff is vt - v.
	local nDv is v:mag * sin(relative_inclination).
	local pDV is v:mag * (cos(relative_inclination) - 1 ).
	local dv is 2 * v:mag * sin(relative_inclination / 2).
	
	
	set tFuturePos to positionat(target,t).
	set sFutureVel to velocityat(ship,t):obt.
	
	if vdot(sFutureVel,tFuturePos) < 0 set nDv to -nDv. 
	if vdot(ship_orbit_normal,tFuturePos) < 0 set nDv to -nDv. 
	
	add node(t, 0, ndv, pDv).
}

///////////////////////////////////////////////////////////////////////////
// Library Functions for utillib included from utillib.ks
///////////////////////////////////////////////////////////////////////////

function burn_duration {
	parameter delta_v_mag, m0 is ship:mass.
	
	local e is constant():e.
	
	local g0 is body:mu / ((ship:orbit:body:radius + ship:altitude) ^ 2).
	
	local ISP is simple_isp().
	
	local m1 is m0*e^(-delta_v_mag / (g0*ISP)).
	
	local burn_dur is (g0*ISP*m0/ship:availablethrust)*(1 - e^(-delta_v_mag/(g0*ISP))).
	
	return list(burn_dur,m1).
}

function simple_isp {
	list engines in engs.
	local totalFlow is 0.
	local totalThrust is 0.
	
	for eng in engs {
		if eng:IGNITION and not eng:FLAMEOUT {
			set totalFlow to totalFlow + (eng:AVAILABLETHRUST / eng:ISP).
			set totalThrust to totalThrust + eng:AVAILABLETHRUST.
		}
	}
	if totalFlow > 0 {
		return totalThrust / totalFlow.
	} else {
		return 0.
	}
}

function half_dv_duration {
	parameter deltav_mag.
	
	local first_half is burn_duration(deltav_mag / 2).
	local first_half_duration is first_half[0].
	
	local second_half is burn_duration(deltav_mag / 2, first_half[1]).
	
	return list(first_half_duration, second_half[0], second_half[1]).
}

function orbital_velocity {
	parameter vessel.
	return (vessel:obt:semimajoraxis + vessel:obt:semiminoraxis) / 2.
}

function orbital_dv {
	parameter v1, v2.
	return sqrt(body:mu / v1) * (sqrt( (2*v2) / (v1+v2) ) -1).
}

function reduce360 {
	parameter ang.
	return ang - 360 * floor(ang/360).
}

///////////////////////////////////////////////////////////////////////////
// End Library utillib
///////////////////////////////////////////////////////////////////////////

