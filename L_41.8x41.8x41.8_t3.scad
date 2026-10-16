// L-shaped angle bracket
// Units: millimeters
// Overall size: 41.8 x 41.8 x 41.8
// Thickness: 3.0

size_x = 41.8;
size_y = 41.8;
size_z = 41.8;
thickness = 3.0;

module l_bracket() {
    union() {
        cube([size_x, thickness, size_z], center = false);
        cube([thickness, size_y, size_z], center = false);
    }
}

color("LightSteelBlue")
    l_bracket();
