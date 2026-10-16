// Open-top box
// Units: millimeters
// Outer size: 41.8 x 41.8 x 41.8
// Wall thickness: 3.0

outer_x = 41.8;
outer_y = 41.8;
outer_z = 41.8;
wall = 3.0;

inner_x = outer_x - 2 * wall;
inner_y = outer_y - 2 * wall;
inner_z = outer_z - wall;

module open_top_box() {
    difference() {
        cube([outer_x, outer_y, outer_z], center = false);

        translate([wall, wall, wall])
            cube([inner_x, inner_y, inner_z + 0.01], center = false);
    }
}

color("LightSteelBlue")
    open_top_box();
