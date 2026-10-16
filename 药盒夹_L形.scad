// L形药盒夹（末端I形推板） - 修改版：末端去掉底板
// 前段为L形角码（底板+侧板），卡在药盒相邻两条边上固定定位；
// 末端14mm底板移除，只留侧板（I形），用以将药盒推出。
// part_id 可选：0=装配效果，1=单独打印件，2=分解示意

part_id = 1;

// ========== 药盒外部参考尺寸（来自药盒子.scad） ==========
box_w = 65.3;      // 药盒外宽
box_d = 45.5;      // 药盒外深
box_h = 13.5;      // 药盒外高
wall  = 1.6;       // 药盒壁厚

// ========== L形夹设计参数（可调） ==========
clip_l     = 100;   // 总长度（L段 + I段）
base_w     = 10;    // 底板宽度：从角线向外延伸，夹住药盒底面
side_h     = 10;    // 侧板高度：从底板向上延伸，夹住药盒侧面
thickness  = 2.0;   // 两块板的板材厚度
inner_r    = 0;     // L形内角圆弧半径；0为直角直板
gap        = 0.3;   // 内侧安装间隙，便于卡入药盒

// ========== 推板参数 ==========
push_l     = 14;    // 末端I形推板长度（移除底板，仅保留侧板）

// ========== 衍生尺寸 ==========
l_l = clip_l - push_l;  // L形段长度

eps = 0.01;

// ========== L形截面（2D） - 底板实体，侧板实体 ==========
module l_profile_2d() {
    difference() {
        union() {
            // 底板截面：沿X方向（实体，无镂空）
            square([base_w + gap + thickness, thickness]);

            // 侧板截面：沿Y方向（实体，无镂空）
            square([thickness, side_h + gap + thickness]);
        }

        // 内角挖掉圆弧填角（使内角圆滑，便于药盒放入）
        if (inner_r > 0) {
            translate([thickness + gap + inner_r, thickness + gap + inner_r])
                circle(r = inner_r, $fn = 60);
            translate([thickness + gap, thickness + gap])
                square([inner_r, inner_r]);
        }
    }
}

// ========== I形截面（2D）：仅侧板（实体，无镂空） ==========
module i_profile_2d() {
    square([thickness, side_h + gap + thickness]);
}

// ========== 带推板的L形夹主体（3D） ==========
// 前段L形 + 末段I形推板
module l_push_clip() {
    // L形段（前段）
    linear_extrude(height = l_l, center = false)
        l_profile_2d();
    // I形推板段（末段，紧接L形段）
    translate([0, 0, l_l])
        linear_extrude(height = push_l, center = false)
            i_profile_2d();
}

// ========== 药盒简化参考体（仅用于装配预览） ==========
module box_reference() {
    color("SteelBlue", 0.3)
        cube([box_w, box_d, box_h]);
}

// ========== 装配效果：L形夹套在药盒右后角 ==========
module assembly() {
    box_reference();

    translate([box_w, box_d, 0])
        rotate([0, 0, 180])
            l_push_clip();
}

// ========== 分解示意 ==========
module exploded_view() {
    box_reference();

    translate([box_w + 10, box_d, 0])
        rotate([0, 0, 180])
            l_push_clip();
}

// ========== 输出 ==========
if (part_id == 1) {
    l_push_clip();
} else if (part_id == 2) {
    exploded_view();
} else {
    assembly();
}
