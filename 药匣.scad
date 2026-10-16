// 盲人取药机 - 配套公/母盒子框架的自由下落药匣
// 公盒子、母盒子作为外部导向框架；本药匣作为内部放药盒，
// 通过外侧竖向导向筋在框架内按 Z 轴方向自由下落。

frame_inner_w = 68;       // 公/母盒子内腔宽度：72 - 2 * 2
frame_inner_d = 48.5;     // 公/母盒子内腔深度：52.5 - 2 * 2

fall_clearance = 0.8;     // 每侧自由下落间隙，打印偏差较大时可加大
guide_t = 0.8;            // 导向筋凸出厚度
guide_w = 7;              // 导向筋在接触面上的宽度
guide_z_margin = 4;       // 导向筋上下避让，减少入口刮擦
rail_overlap = 0.2;       // 导向筋嵌入主体，保证不是贴面悬浮

cart_w = frame_inner_w - 2 * fall_clearance;  // 药匣最大外廓宽度
cart_d = frame_inner_d - 2 * fall_clearance;  // 药匣最大外廓深度
cart_h = 112;             // 药匣高度，低于 140mm 框架高度

core_w = cart_w - 2 * guide_t;
core_d = cart_d - 2 * guide_t;
wall = 2;                 // 药匣壁厚

funnel_h = 36;            // 内部漏斗高度
outlet_w = 24;            // 出药口宽度，适配 25mm 小抽屉
outlet_d = 18;            // 出药口深度

eps = 0.02;

core_x = guide_t;
core_y = guide_t;

inner_x = core_x + wall;
inner_y = core_y + wall;
inner_w = core_w - 2 * wall;
inner_d = core_d - 2 * wall;

outlet_x = (cart_w - outlet_w) / 2;
outlet_y = (cart_d - outlet_d) / 2;

guide_h = cart_h - 2 * guide_z_margin;

module core_body() {
    translate([core_x, core_y, 0])
        cube([core_w, core_d, cart_h], center=false);
}

module guide_rails() {
    // 左右两侧导向筋控制 X 方向间隙。
    translate([0, core_y + 7, guide_z_margin])
        cube([guide_t + rail_overlap, guide_w, guide_h], center=false);
    translate([0, core_y + core_d - 7 - guide_w, guide_z_margin])
        cube([guide_t + rail_overlap, guide_w, guide_h], center=false);

    translate([cart_w - guide_t - rail_overlap, core_y + 7, guide_z_margin])
        cube([guide_t + rail_overlap, guide_w, guide_h], center=false);
    translate([cart_w - guide_t - rail_overlap, core_y + core_d - 7 - guide_w, guide_z_margin])
        cube([guide_t + rail_overlap, guide_w, guide_h], center=false);

    // 前后两侧导向筋控制 Y 方向间隙。
    translate([core_x + 9, 0, guide_z_margin])
        cube([guide_w, guide_t + rail_overlap, guide_h], center=false);
    translate([core_x + core_w - 9 - guide_w, 0, guide_z_margin])
        cube([guide_w, guide_t + rail_overlap, guide_h], center=false);

    translate([core_x + 9, cart_d - guide_t - rail_overlap, guide_z_margin])
        cube([guide_w, guide_t + rail_overlap, guide_h], center=false);
    translate([core_x + core_w - 9 - guide_w, cart_d - guide_t - rail_overlap, guide_z_margin])
        cube([guide_w, guide_t + rail_overlap, guide_h], center=false);

    // 前面中间加一条较宽方向筋，方便辨认出药方向。
    translate([(cart_w - 12) / 2, 0, guide_z_margin])
        cube([12, guide_t + rail_overlap, guide_h], center=false);
}

module storage_void() {
    translate([inner_x, inner_y, funnel_h - eps])
        cube([inner_w, inner_d, cart_h - funnel_h + 2 * eps], center=false);
}

module gravity_funnel_void() {
    hull() {
        translate([inner_x, inner_y, funnel_h - eps])
            cube([inner_w, inner_d, eps], center=false);

        translate([outlet_x, outlet_y, -eps])
            cube([outlet_w, outlet_d, eps], center=false);
    }
}

module top_chamfer_void() {
    // 顶部内侧倒角，减少装药时卡在边缘。
    translate([inner_x - 1, inner_y - 1, cart_h - 5])
        cube([inner_w + 2, inner_d + 2, 6], center=false);
}

module medicine_cartridge() {
    difference() {
        union() {
            core_body();
            guide_rails();
        }

        storage_void();
        gravity_funnel_void();
        top_chamfer_void();
    }
}

medicine_cartridge();
