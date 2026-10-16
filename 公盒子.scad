// 盲人取药机 - 公盒子 (上下通透，四面围栏，四角带凸起)

box_w = 72;           // 盒子宽度 (X轴)
box_d = 52.5;         // 盒子深度 (Y轴)
box_h = 140;          // 盒子高度 (Z轴)
wall_thickness = 2;   // 壁厚

corner_size = 18;     // 凸起沿墙体方向的长度（略小于缺口2mm，留间隙）
protrude_h = 12;      // 凸起高度
anchor_overlap = 1;   // 向盒体内重叠，避免只有面接触导致切片分离

module father_box() {
    union() {
        // 主体：四面围栏（上下通透）
        difference() {
            cube([box_w, box_d, box_h], center=false);

            translate([wall_thickness, wall_thickness, -1])
                cube([
                    box_w - 2*wall_thickness,
                    box_d - 2*wall_thickness,
                    box_h + 2
                ], center=false);
        }

        // 四角L形凸起，只长在墙体上，保持中间完全通透
        // 左前角
        translate([0, 0, box_h - anchor_overlap])
            cube([corner_size, wall_thickness, protrude_h + anchor_overlap], center=false);
        translate([0, 0, box_h - anchor_overlap])
            cube([wall_thickness, corner_size, protrude_h + anchor_overlap], center=false);
        // 右前角
        translate([box_w - corner_size, 0, box_h - anchor_overlap])
            cube([corner_size, wall_thickness, protrude_h + anchor_overlap], center=false);
        translate([box_w - wall_thickness, 0, box_h - anchor_overlap])
            cube([wall_thickness, corner_size, protrude_h + anchor_overlap], center=false);
        // 左后角
        translate([0, box_d - wall_thickness, box_h - anchor_overlap])
            cube([corner_size, wall_thickness, protrude_h + anchor_overlap], center=false);
        translate([0, box_d - corner_size, box_h - anchor_overlap])
            cube([wall_thickness, corner_size, protrude_h + anchor_overlap], center=false);
        // 右后角
        translate([box_w - corner_size, box_d - wall_thickness, box_h - anchor_overlap])
            cube([corner_size, wall_thickness, protrude_h + anchor_overlap], center=false);
        translate([box_w - wall_thickness, box_d - corner_size, box_h - anchor_overlap])
            cube([wall_thickness, corner_size, protrude_h + anchor_overlap], center=false);
    }
}

// 渲染公盒子
father_box();
