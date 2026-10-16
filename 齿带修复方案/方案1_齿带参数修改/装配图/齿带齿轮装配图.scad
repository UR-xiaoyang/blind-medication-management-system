// 齿带齿轮装配图 - 展示齿带（粘接在底板）的工作状态
// 方案1：让齿带紧贴齿轮，解决滑扣问题
// 注意：U形推头独立打印，齿带粘在底板上

include <rack_params.scad>
use <gear.scad>
use <pusher_face.scad>
use <bearing_block.scad>

// ====== 方案1修复参数 ======
rack_sleeve_thick = 1.0;    // 齿带本体厚度
rack_w_extended = 9.0;      // 齿带宽度 (8→9mm)
teeth_height_belt = 1.2;    // 齿高 (1.0→1.2mm)
groove_depth_for_belt = 5.5; // 安装槽深度

// ====== 齿带组件（粘接在底板）======
module rack_belt() {
    color("SteelBlue", 0.9)
    // 齿带本体
    cube([rack_len, rack_w_extended, rack_sleeve_thick]);

    // 齿形（粘在齿带顶面）
    color("DodgerBlue", 0.8)
    for(i=[0:tooth_cnt-1]) {
        translate([i * pitch + tooth_thick/2, 0, rack_sleeve_thick - 0.02])
        cube([tooth_thick, rack_w_extended, teeth_height_belt]);
    }
}

// ====== 底板及齿带安装槽 ======
module base_with_belt_groove() {
    color("LightGray", 0.3)
    difference() {
        cube([base_w, base_l, base_t]);

        // 主滑槽（让U形推头能滑动）
        translate([(base_w - groove_w)/2, 0, base_t - groove_d])
        cube([groove_w, base_l, groove_d + eps]);

        // 齿带安装槽（让齿带紧贴底板）
        translate([0, groove_d + 5, base_t - groove_depth_for_belt])
        cube([rack_w_extended + 1, rack_len + 1, groove_depth_for_belt + 1]);
    }
}

// ====== 完整装配 ======

// 底板
translate([0, 0, 0])
base_with_belt_groove();

// 齿轮
color("DodgerBlue", 0.7)
translate([gear_cx, gear_cy, gear_cz - gear_w/2])
spur_gear();

// 轴座
color("SlateGray")
for(side=[-1, 1])
translate([gear_cx + side * (gear_outer_r + bearing_block_w/2 + 2),
           bearing_y, -rack_thick/2])
bearing_block();

// 齿带（粘在底板凹槽中，与齿轮啮合）
translate([rack_x - 0.5, -5, -rack_sleeve_thick - 0.5])
rack_belt();

// L形推头（齿条末端的推药块）
color("OrangeRed", 0.8)
translate([rack_x, rack_y0 + rack_len, rack_z])
pusher_face();

// ====== 侧视图（展示啮合）======
translate([rack_x + rack_len + 8, 0, -groove_depth_for_belt/2])
{
    // 齿轮（剖面）
    color("DodgerBlue", 0.6)
    translate([5, 0, groove_depth_for_belt/2])
    cylinder(h=rack_w_extended + 2, d=gear_outer_r * 2, $fn=60);

    // 齿带（侧视）
    color("SteelBlue", 0.8)
    translate([0, 0, 0])
    cube([rack_len, 0.6, rack_sleeve_thick + teeth_height_belt]);

    // 啮合标记
    color("Red", 0.7)
    translate([rack_len/2, -2, groove_depth_for_belt/2 + rack_sleeve_thick])
    {
        linear_extrude(height=1)
            text("啮合面", size=5);
    }
}
