// Rectangular block
// Units: millimeters
// Size: 79.1 x 63.9 x 15.9

length = 79.1;
width = 63.9;
height = 15.9;

module block() {
    cube([length, width, height], center = true);
}

color("LightSteelBlue")
    block();

