// shaft.scad - φ6.5 × 20mm 电机轴套（直接用电机轴，不需打印）
// 局部坐标系：轴中心在 (0,0,0)，Z 从 -shaft_len/2 到 +shaft_len/2
// 用途：直接使用 6.5mm 电机轴，穿过齿轮中心，由两侧轴座支撑
// 此文件保留作参考，实际装配时直接用电机轴即可，不需要打印

include <rack_params.scad>

module shaft() {
    color("Silver")
    translate([0, 0, -shaft_len / 2])
        cylinder(h = shaft_len, r = shaft_d / 2, center = false, $fn = 24);
}

// 独立渲染（参考用）
shaft();
