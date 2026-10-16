// 齿条 (Rack) - 3D 模型
// 单位: 毫米 (mm)

// 基础参数
$fn = 50;

pitch = 4.0;
tooth_height = 2.25;
tooth_thickness = 2.0;
width = 12.0;
num_teeth = 30;           // 齿数量 (120mm长度)

total_length = num_teeth * pitch;
total_height = tooth_height * 2;

// 基础底板
cube([total_length, tooth_height, width]);

// 添加齿形
for (i = [0 : num_teeth - 1]) {
    translate([i * pitch + tooth_thickness/2, tooth_height, 0])
    cube([tooth_thickness, tooth_height, width]);
}