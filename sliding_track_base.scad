// sliding_track_base.scad
// Sliding track base for the U-shaped pusher block.
// Units: mm

// ====== Base outline ======
base_w = 75;           // X width
base_l = 140;          // Y length
base_t = 5.9;          // Z thickness

// ====== U-pusher rail grooves ======
rail_w       = 2;      // Groove width, matching the 2 mm pusher walls
rail_d       = 2.5;    // Groove depth from the top surface
rail_chamfer = 2;      // Entry chamfer at Y=0

// Grooves are symmetric around base center X=37.5:
// left: X=[14,16], right: X=[59,61].
rail_cx_left  = 15;
rail_cx_right = 60;

// ====== Mounting holes ======
mount_hole_d  = 3.2;   // M3 clearance hole
mount_inset   = 8;
mount_x_left  = 30;
mount_x_right = 45;

// ====== Side blocker slots ======
side_slot_w = 4;
side_slot_d = 4;

eps = 0.01;

module rail_groove(cx) {
    translate([cx - rail_w/2, 0, base_t - rail_d])
        cube([rail_w, base_l, rail_d + eps]);
}

module rail_entry_chamfer(cx) {
    translate([cx - rail_w/2, -eps, base_t - rail_d - eps])
        rotate([0, 0, 45])
            cube([rail_w, rail_chamfer * sqrt(2), rail_d + 2*eps]);
}

module sliding_track_base() {
    difference() {
        cube([base_w, base_l, base_t]);

        rail_groove(rail_cx_left);
        rail_groove(rail_cx_right);

        rail_entry_chamfer(rail_cx_left);
        rail_entry_chamfer(rail_cx_right);

        translate([mount_x_left, mount_inset, -eps])
            cylinder(d=mount_hole_d, h=base_t + 2*eps, $fn=30);
        translate([mount_x_right, base_l - mount_inset, -eps])
            cylinder(d=mount_hole_d, h=base_t + 2*eps, $fn=30);

        for (xside = [0, base_w - side_slot_w]) {
            translate([xside, 0, base_t - side_slot_d])
                cube([side_slot_w, base_l, side_slot_d + eps]);
        }
    }
}

sliding_track_base();