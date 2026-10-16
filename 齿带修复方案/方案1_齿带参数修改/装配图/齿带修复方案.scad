// 盲人抓药机 - 齿带修复方案 v1.0
// 方案1：修改齿带参数让其更贴紧齿轮，解决滑扣问题
// 本文件是完整组合图，包含所有修改后的零件和工作状态演示

include <rack_params.scad>
// 导入修复后的共享参数
include <滑动导轨共享参数.scad> // 从原滑动导轨参数中提取

// ====== 修改后的齿条参数 ======
// 针对齿带+电机方案的滑扣问题进行的修复

// Original parameters from rack_params.scad
default_track_thick = 3.5; // 原始齿条厚度

// 方案1修复措施：
// 1. 增加齿条基体厚度，让齿带有足够的强度
rack_total_thick = 5.0; // 齿带+基体总厚度 (原3.5→5.0)
gear_rail_thickness = rack_total_thick; // 齿轮轨道厚度也同步增加

// 2. 降低齿高，增加强度，防止变形
rack_teeth_height = 1.5; // 齿高从默认2mm降低到1.5mm ，增加强度
gear_pcd = gear_teeth * modulus; // 基圆直径
gear_base_r = gear_root_r + (rack_teeth_height * 0.7); // 轮基半径，让齿带更贴齿轮

// 3. 增加齿面宽度，改善啮合
rack_teeth_width = rack_w + 1.0; // 齿面宽度增加1mm (8mm→9mm)

// 4. 优化齿间隙，让齿带可以贴紧齿轮表面
teeth_clearance = 0.2; // 齿与齿轮啮合间隙: 0.2mm (之前可能0.5mm)

// 5. 轨道凹槽深度修正
rail_groove_depth = base_t + 2; // 让齿条可以更低地贴合底板

// 齿条推杆总高度修正，确保可以顶起药盒
pusher_total_height = base_t + 5; // 底板厚度+顶起药盒需要的高度

// ====== 齿条基体（齿带粘贴平台）======
module rack_base_body() {
    color("LightSteelBlue", 0.9)
    difference() {
        // 齿条基体：比齿面更长更厚的支撑平台
        cube([rack_w + 2, track_base_h + 5, rack_total_thick]);

        // 顶部齿形凹槽（让齿带可以卡进去并用胶水粘贴固定）
        translate([1, 2, 0])
        import("rack_gear_cutout.scad"); // 预计算的齿形凹槽用于切割

        // 中心轴孔（让推杆从下方上来）
        translate([(rack_w) / 2, track_base_h/2 - 1, 0])
        cylinder(d=shaft_d + 0.5, h=rack_total_thick + 2, center=true);
    }
}

// ====== 修复后的齿条总成（含齿带）======
module fixed_rack_assembly() {
    color("SteelBlue", 0.8)

    // 齿条基体（齿带粘贴的平台）
    translate([rack_x, track_base_h/2 - 2, rail_groove_depth - rack_total_thick - 1])
    rack_base_body();

    // 齿带条：实际推动药盒的部分 (70×8×1.5mm)
    translate([rack_x + 1, track_base_h/2 - 2, rail_groove_depth - rack_teeth_height])
    cube([rack_len - 2, rack_teeth_width, rack_teeth_height]);

    // 推头：将齿带的运动转化为药盒的平动
    translate([rack_x + 5, track_base_h/2 - 2 + (rack_teeth_width/2 - pusher_tab_t/2), rail_groove_depth - pusher_total_height])
    {
        color("OrangeRed")
        difference() {
            // 推头主体
            cube([rack_w - 8, pusher_tab_t, pusher_total_height]);

            // 与齿带啮合的部分（防滑）
            translate([rack_w/4, 0, rack_teeth_height/2 - 0.5])
            cube([rack_w/2 - 1, pusher_tab_t, rack_teeth_height - 0.3]);
        }
    }
}

// ====== 齿轮组件（与齿带啮合）======
module fixed_gear_assembly() {
    color("DodgerBlue", 0.8)

    // 齿轮基体
    difference() {
        cylinder(h=gear_w + 1, d=gear_outer_r * 2, $fn=80);

        // 轴孔
        cylinder(h=gear_w + 2, d=shaft_d, $fn=30);
    }

    // 齿形：重新参数化，让齿更矮更厚，降低滑扣风险
    for(i=[0:teeth_clearance:rack_len]) {
        rotate([0, 0, i * 360/gear_teeth])
        translate([gear_root_r, 0, -rack_teeth_height/2])
        cube([rack_teeth_width, rack_total_thick * 0.8, rack_teeth_height]);
    }
}

// ====== 轨道组件 ======
module rail_track() {
    color("DimGray", 0.3)
    difference() {
        // 轨道凹槽主体
        cube([rack_w + 5, base_l, base_t + 2]);

        // 齿轮配合槽
        translate([-1, 0, 0])
        cube([gear_outer_r * 2 + 5, base_l, gear_rail_thickness + 2]);

        // 中心轴孔
        translate([(rack_w+2)/2, 0, -2])
        cylinder(d=shaft_d + 3, h=gear_rail_thickness + 4, center=false);
    }
}

// ====== 工作状态演示 ======
// 模拟齿条被推动的过程，展示齿带+齿轮的工作状态
module working_state_demo() {
    color("white")
    translate([0, -50, pusher_total_height * -1])

    // 状态1：初始位置（齿带与齿轮啮合齐平）
    translate([rack_x, 0, rail_groove_depth - pusher_total_height + 1])
    {
        text(text="状态1: 初始位置", size=8, halign="center")
        fixed_rack_assembly();
    }

    // 状态2：推头前进0.5个齿距（齿带已推动8mm）
    translate([rack_x + rack_teeth_height * 3, 0, 0])
    {
        text(text="状态2: 推动5mm", size=8, halign="center")
        translate([0, rack_teeth_width/2 + 15, 0]) {
            fixed_rack_assembly();
        }
    }

    // 状态3：推头前进1.0个齿距（齿带已推动完整的1个齿距）
    translate([rack_x + rack_teeth_height * 8, 0, 0])
    {
        text(text="状态3: 推动完成", size=8, halign="center")
        translate([0, rack_teeth_width/2 + 30, 0]) {
            fixed_rack_assembly();
            fixed_gear_assembly();
        }
    }
}

// ====== 最终组合图打印函数 ======
// F5预览可以看到所有部件
// F6渲染可以用于制造示意图

// 主视图：修复后的完整组合（覆盖图）
translate([0, 0, 0])
{
    // 轨道系统
    rail_track();

    // 齿带总成
    translate([10, 10, 0])
    fixed_rack_assembly();

    // 齿轮系统
    translate([35, 10, -gear_rail_thickness/2])
    rotate([90, 0, 0])
    fixed_gear_assembly();

    // 工作状态演示（右侧）
    working_state_demo();
}

// ====== 侧视图（展示几何关系）======
translate([60, -120, -pusher_total_height * 0.8])
{
    // 从侧面看：齿带+齿轮的啮合关系
    text(text="齿带与齿轮啮合侧视图", size=6, halign="center")

    // 齿带条
    translate([rack_x + 10, 0, rail_groove_depth])
    cube([rack_len + 5, rack_teeth_width, rack_teeth_height]);

    // 显示齿轮基圆
    color("DeepSkyBlue")
    translate([rack_x + rack_len/2, rack_teeth_width/2, rail_groove_depth - gear_base_r])
    cylinder(h=rack_teeth_width + 5, d=gear_base_r*2, $fn=60);

    // 显示齿轮啮合起点（红色标记）
    color("Red", 0.5)
    translate([rack_x + 5, rack_teeth_width/2 - 1, rail_groove_depth - gear_base_r - rack_teeth_height/2])
    sphere(d=rack_teeth_height);
}

// ====== 重要尺寸标注 ======
module add_dimensions() {
    // 齿带总厚：5mm（基体2mm+齿面1.5mm+余量1.5mm）
    color("black")
    translate([rack_x, -30, rail_groove_depth + rack_total_thick/2])
    {
        text(str("齿带总厚度: ", rack_total_thick, "mm"), size=5, halign="center");
    }

    // 齿高：1.5mm（相比之前2mm降低，强度更好）
    translate([rack_x + rack_len/2, -30, rail_groove_depth + rack_teeth_height/2])
    {
        text(str("齿高: ", rack_teeth_height, "mm"), size=5, halign="center");
    }

    // 啮合间隙标注
    color("Blue")
    translate([rack_x + rack_len/2, rack_teeth_width/2 + 20, rail_groove_depth + rack_total_thick/3])
    {
        text(str("啮合间隙: ", teeth_clearance, "mm"), size=5, halign="center");
        cube([rack_teeth_width, 0.5, rack_total_thick * 0.2]);
    }
}

// 渲染时自动添加尺寸标注
add_dimensions();

