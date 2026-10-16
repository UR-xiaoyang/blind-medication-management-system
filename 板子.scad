// ============================================================
// 板子 / Flat Plate
// 尺寸: 170mm × 149mm × 2mm
// ============================================================

// ---------- 参数 ----------
plate_length = 170;   // X 方向长度 (mm)
plate_width  = 149;   // Y 方向宽度 (mm)
plate_thick  = 2;     // Z 方向厚度 (mm)

// 圆角半径 (设为 0 表示直角)
corner_radius = 0;

// 渲染精度
$fn = 64;

// ---------- 主模型 ----------
module plate(L = plate_length, W = plate_width, T = plate_thick, r = corner_radius) {
    if (r > 0) {
        // 带圆角的板子
        hull() {
            translate([r,         r,         0]) cylinder(h = T, r = r);
            translate([L - r,     r,         0]) cylinder(h = T, r = r);
            translate([r,         W - r,     0]) cylinder(h = T, r = r);
            translate([L - r,     W - r,     0]) cylinder(h = T, r = r);
        }
    } else {
        // 直角板子
        cube([L, W, T]);
    }
}

// ---------- 渲染 ----------
plate();

// ---------- 信息输出 ----------
echo(str("板子尺寸: ", plate_length, " × ", plate_width, " × ", plate_thick, " mm"));
echo(str("板子面积: ", plate_length * plate_width / 100, " cm²"));
echo(str("板子体积: ", plate_length * plate_width * plate_thick / 1000, " cm³"));
