// gear.scad
// Spur gear: 12.9 mm outer diameter, 2.9 mm bore.
include <rack_params.scad>
include <MCAD/involute_gears.scad>

gear_outer_d = 12.9;
gear_bore_d = 2.9;
gear_profile_offset = 0.05;
gear_local_modulus = gear_outer_d / (gear_teeth + 2);
gear_local_pitch_r = gear_teeth * gear_local_modulus / 2;
gear_local_outer_r = gear_outer_d / 2 - gear_profile_offset;
gear_local_root_r = gear_local_pitch_r - 1.2 * gear_local_modulus;

module spur_gear() {
    color("DodgerBlue")
    difference() {
        linear_extrude(height = gear_w, center = false)
            offset(r = gear_profile_offset)
            gear_shape(
                number_of_teeth = gear_teeth,
                pitch_radius = gear_local_pitch_r,
                root_radius = gear_local_root_r,
                base_radius = gear_local_pitch_r * cos(20),
                outer_radius = gear_local_outer_r,
                half_thick_angle = 360 / gear_teeth / 4,
                involute_facets = 12
            );

        translate([0, 0, -eps])
            cylinder(h = gear_w + 2 * eps, r = gear_bore_d / 2, center = false, $fn = 30);
    }
}

spur_gear();
