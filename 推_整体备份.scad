// 盲人取药机 - 齿条齿轮驱动药盒推出模块
// 适配底板：sliding_track_base.scad（base_w=30, base_l=90, base_t=5）
// 适配药盒：子弹.scad（25x35x15mm, 底厚 1.5mm）
// 驱动：模数1.0 齿条 + 齿轮，电机轴径3mm

// ---------- 全局参数 ----------

// 底板参数（来自 sliding_track_base.scad，仅引用不修改）
base_w  = 30;
base_l  = 90;
base_t  = 5;
groove_w = 26;
groove_d = 2;

// 齿条参数
modulus    = 1.0;
pitch      = PI * modulus;
addendum   = 1.0 * modulus;
dedendum   = 1.2 * modulus;
tooth_thick = pitch / 2;
rack_w     = 8;
rack_thick = 3.5;
rack_len   = 70;
tooth_cnt  = floor(rack_len / pitch);

// 推头参数
pusher_w     = 23;
pusher_tab_t = 1.5;
pusher_arm_t = 1.5;

// 齿轮参数
gear_teeth  = 20;
gear_r      = gear_teeth * modulus / 2;
gear_outer_r = gear_r + addendum;
gear_root_r  = gear_r - dedendum;
gear_w      = rack_w;
shaft_d     = 3;
shaft_len   = 20;

// 轴座参数
bearing_block_w  = 12;
bearing_block_d  = 10;
bearing_block_h  = 8;
bearing_hole_d   = 3.2;
mount_hole_d     = 3.2;

// 装配坐标
rack_x = (base_w - rack_w) / 2;
rack_z = -rack_thick;
rack_y0 = -20;

gear_cx = base_w / 2;
gear_cy = base_l - 5;
gear_cz = rack_z + rack_thick / 2;

bearing_y = gear_cy;
mount_inset = 6;
eps = 0.01;

// 模块 1：单个齿条齿（梯形齿廓）
module rack_tooth_profile() {
    bw = tooth_thick + 0.3;
    tw = tooth_thick - 0.3;
    rotate([90, 0, 90])
    linear_extrude(height = rack_w, center = false)
        polygon(points = [
            [-bw/2, 0],
            [ bw/2, 0],
            [ tw/2, addendum],
            [-tw/2, addendum]
        ]);
}

// 模块 2：齿条（基体 + 齿阵列）
module rack() {
    color("SteelBlue")
    union() {
        cube([rack_w, rack_len, rack_thick - addendum]);
        for (i = [0 : tooth_cnt - 1]) {
            translate([0, i * pitch, rack_thick - addendum])
                rack_tooth_profile();
        }
    }
}

// 模块 3：L 形推头
module pusher_head() {
    color("OrangeRed")
    union() {
        // 竖板：穿过凹槽
        translate([(rack_w - pusher_w) / 2, -pusher_tab_t, rack_thick - addendum])
            cube([pusher_w, pusher_tab_t, base_t - (rack_thick - addendum) + addendum]);

        // 横板（托板）：在凹槽上方
        translate([(rack_w - pusher_w) / 2, -pusher_tab_t - 15, base_t])
            cube([pusher_w, 15 + pusher_tab_t, pusher_arm_t]);

        // 加强筋
        hull() {
            translate([0, -0.1, rack_thick - addendum])
                cube([rack_w, 0.1, 0.1]);
            translate([(rack_w - pusher_w) / 2, -pusher_tab_t, base_t - 0.1])
                cube([pusher_w, 0.1, 0.1]);
        }
    }
}

// 模块 4：齿条+推头总成
module rack_assembly() {
    translate([rack_x, rack_y0, rack_z]) {
        rack();
        translate([0, rack_len, 0])
            pusher_head();
    }
}

// 模块 5：齿轮齿廓截面（梯形近似）
module gear_tooth_2d() {
    bw = 2 * gear_r * sin(tooth_thick / (2 * gear_r) * 180 / PI);
    tw = bw * 0.65;
    polygon(points = [
        [-bw/2, 0],
        [ bw/2, 0],
        [ tw/2, addendum],
        [-tw/2, addendum]
    ]);
}

// 模块 6：直齿圆柱齿轮
module spur_gear() {
    color("DodgerBlue")
    difference() {
        union() {
            cylinder(h = gear_w, r = gear_root_r, center = false, $fn = 80);
            for (i = [0 : gear_teeth - 1]) {
                angle = i * 360 / gear_teeth;
                rotate([0, 0, angle])
                    translate([gear_r, 0, 0])
                        linear_extrude(height = gear_w, center = false)
                            gear_tooth_2d();
            }
        }
        translate([0, 0, -eps])
            cylinder(h = gear_w + 2 * eps, r = shaft_d / 2, center = false, $fn = 30);
    }
}

// 模块 7：轴
module shaft() {
    color("Silver")
    translate([0, 0, -shaft_len / 2])
        cylinder(h = shaft_len, r = shaft_d / 2, center = false, $fn = 24);
}

// 模块 8：轴座
module bearing_block() {
    color("SlateGray")
    difference() {
        union() {
            cube([bearing_block_w, bearing_block_d, bearing_block_h]);
            cube([bearing_block_w, bearing_block_d + 8, 3]);
        }
        translate([-eps, bearing_block_d / 2, bearing_block_h / 2])
            rotate([0, 90, 0])
                cylinder(h = bearing_block_w + 2 * eps, r = bearing_hole_d / 2, $fn = 24);
        translate([bearing_block_w / 2, bearing_block_d + 4, -eps])
            cylinder(h = 3 + 2 * eps, r = mount_hole_d / 2, $fn = 24);
    }
}

// 模块 9：齿轮总成
module gear_assembly() {
    translate([gear_cx, gear_cy, gear_cz - gear_w / 2])
        spur_gear();

    translate([gear_cx, gear_cy, 0])
        shaft();

    translate([gear_cx - bearing_block_w - gear_outer_r - 1, bearing_y - bearing_block_d / 2, 0])
        bearing_block();

    translate([gear_cx + gear_outer_r + 1, bearing_y - bearing_block_d / 2, 0])
        bearing_block();
}

// 模块 10：完整推出模块总成
module pusher_assembly() {
    rack_assembly();
    gear_assembly();
}

// 渲染：完整总成 + 半透明底板（仅用于空间验证）
pusher_assembly();

%translate([0, 0, 0])
    sliding_track_base_ref();

module sliding_track_base_ref() {
    color("LightGray", 0.3)
    difference() {
        cube([base_w, base_l, base_t]);
        translate([(base_w - groove_w) / 2, 0, base_t - groove_d])
            cube([groove_w, base_l, groove_d + eps]);
    }
}
