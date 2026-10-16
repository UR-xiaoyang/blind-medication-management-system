// 68mm x 47.5mm x 3mm 平板
// 单位: mm

length = 68;
width = 47.5;
thickness = 3;

// 倒角 (圆角半径)
$fn = 64;

module plate() {
    minkowski() {
        cube([length - 2, width - 2, thickness/2], center = true);
        cylinder(r = 1, h = thickness/2);
    }
}

color("SteelBlue")
    translate([0, 0, 0])
        plate();

// 中心标记
%color("Red")
    translate([0, 0, thickness/2 + 0.1])
        cylinder(d = 1, h = 0.1);
