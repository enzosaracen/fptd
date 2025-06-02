module top (
    input wire clk,
    input wire rst_n,
    input wire btnU,
	input wire btnD,
	input wire btnL,
	input wire btnR,
	input wire btnC,
	input wire btn1,
	input wire btn2,
	input wire btn3,
	input wire btn4,
    output wire hsync,
    output wire vsync,
    output wire [3:0] red,
    output wire [3:0] green,
    output wire [3:0] blue
);
    localparam H_VISIBLE = 640, H_FP = 16, H_PW = 96, H_BP = 48,
               V_VISIBLE = 480, V_FP = 10, V_PW =  2, V_BP = 33;

    reg [9:0] h_cnt, v_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 0; v_cnt <= 0;
        end else begin
            if (h_cnt == H_VISIBLE+H_FP+H_PW+H_BP-1) begin
                h_cnt <= 0;
                v_cnt <= (v_cnt == V_VISIBLE+V_FP+V_PW+V_BP-1) ? 0 : v_cnt + 1;
            end else begin
                h_cnt <= h_cnt + 1;
            end
        end
    end

    assign hsync = ~(h_cnt >= H_VISIBLE+H_FP &&
                     h_cnt <  H_VISIBLE+H_FP+H_PW);
    assign vsync = ~(v_cnt >= V_VISIBLE+V_FP &&
                     v_cnt <  V_VISIBLE+V_FP+V_PW);

    wire visible = (h_cnt < H_VISIBLE) && (v_cnt < V_VISIBLE);
    main_scene scene_i (
		.clk (clk),
		.rst_n (rst_n),
        .visible (visible),
        .x (h_cnt),
        .y (v_cnt),
        .btnU (btnU),
        .btnD (btnD),
        .btnL (btnL),
        .btnR (btnR),
        .btnC (btnC),
        .btn1 (btn1),
        .btn2 (btn2),
        .btn3 (btn3),
        .btn4 (btn4),
        .red (red),
        .green (green),
        .blue (blue)
    );
endmodule
