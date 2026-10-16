// 推出模块共享参数 - 所有零件文件和装配预览文件通过 include 引用此文件
// 此文件仅放参数定义（变量赋值），不放任何 geometry 语句

// ---------- 底板参数 (引用自 sliding_track_base.scad) ----------
base_w   = 30;
base_l   = 90;
base_t   = 5;
groove_w = 26;
groove_d = 1.5;

// ---------- 齿条参数 ----------
modulus     = 1.0;                    // 齿轮模数
pitch       = PI * modulus;           // 齿距 p
addendum    = 1.0 * modulus;          // 齿顶高
dedendum    = 1.2 * modulus;          // 齿根高
tooth_thick = pitch / 2;              // 齿厚

rack_w     = 8;                       // 齿条宽 (X)
rack_thick = 3.5;                     // 齿条厚 (Z) - 仅含齿高部分（与齿轮啮合计算用）
rack_base_h = 5;                      // 齿条基体加厚高度（专门为底部粘贴预留），不含齿高
rack_len   = 140;                     // 齿条长 (Y) — 由原 70mm 改为 140mm
tooth_cnt  = floor(rack_len / pitch); // 齿条齿数

// ---------- 推头参数 ----------
pusher_w     = 23;                    // 推头宽 (< groove_w=26)
pusher_tab_t = 1.5;                   // 竖板厚 (< groove_d=1.5)
pusher_arm_t = 1.5;                   // 横板厚
blocker_h    = 20;                    // 竖板总高度（从齿条顶面起算）= 底板厚(5) + 药盒高(13.5) + 余量(1.5)
                                     //  作用：推头到达行程终点时高出底板 15mm 堵住上方药匣出药口

// ---------- 齿轮参数 ----------
gear_teeth   = 20;                    // 齿轮齿数
gear_r       = gear_teeth * modulus / 2;   // 分度圆半径
gear_outer_r = gear_r + addendum;          // 齿顶圆半径
gear_root_r  = gear_r - dedendum;          // 齿根圆半径
gear_w       = rack_w;                     // 齿轮厚度 (Z)
shaft_d      = 6.5;                         // 电机轴径（6.5mm 轴孔）
shaft_len    = 20;                         // 轴长

// ---------- 轴座参数 ----------
bearing_block_w = 12;
bearing_block_d = 10;
bearing_block_h = 8;
bearing_hole_d  = 6.7;                     // 6.5mm电机轴 + 0.2mm间隙
mount_hole_d    = 3.2;                     // M3 安装孔

// ---------- 装配坐标 ----------
rack_x   = (base_w - rack_w) / 2;         // 齿条X起点 (底板X中心)
rack_z   = -rack_thick;                   // 齿条Z底面 (底板Z=0下方)
rack_y0  = -20;                           // 齿条Y起点 (在底板Y=0外)

gear_cx = base_w / 2;                     // 齿轮X中心
gear_cy = base_l - 5;                     // 齿轮Y中心 (底板Y=90末端内侧)
gear_cz = rack_z + rack_thick / 2;        // 齿轮Z中心 (齿条厚度中线)

bearing_y   = gear_cy;                    // 轴座Y中心
mount_inset = 5;
eps         = 0.01;
