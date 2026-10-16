// 盲人取药机 - 母盒子 (上下通透，四面围栏，四角带缺口)

box_w = 72;           // 盒子宽度 (X轴)
box_d = 52.5;         // 盒子深度 (Y轴)
box_h = 140;          // 盒子高度 (Z轴)
wall_thickness = 2;   // 壁厚

corner_size = 20;     // 缺口沿墙体方向的长度
indent_h = 15;        // 缺口深度

module mother_box() {
    difference() {
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

        // 四角L形缺口，只切墙体，保持中间完全通透
        // 左前角 (X=0, Y=0)
        translate([0, 0, box_h - indent_h])
            cube([corner_size, wall_thickness, indent_h + 1], center=false);
        translate([0, 0, box_h - indent_h])
            cube([wall_thickness, corner_size, indent_h + 1], center=false);
        // 右前角 (X=max, Y=0)
        translate([box_w - corner_size, 0, box_h - indent_h])
            cube([corner_size, wall_thickness, indent_h + 1], center=false);
        translate([box_w - wall_thickness, 0, box_h - indent_h])
            cube([wall_thickness, corner_size, indent_h + 1], center=false);
        // 左后角 (X=0, Y=max)
        translate([0, box_d - wall_thickness, box_h - indent_h])
            cube([corner_size, wall_thickness, indent_h + 1], center=false);
        translate([0, box_d - corner_size, box_h - indent_h])
            cube([wall_thickness, corner_size, indent_h + 1], center=false);
        // 右后角 (X=max, Y=max)
        translate([box_w - corner_size, box_d - wall_thickness, box_h - indent_h])
            cube([corner_size, wall_thickness, indent_h + 1], center=false);
        translate([box_w - wall_thickness, box_d - corner_size, box_h - indent_h])
            cube([wall_thickness, corner_size, indent_h + 1], center=false);
    }
}

// 渲染母盒子
mother_box();
