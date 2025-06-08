module top (
    input wire clk,
    input wire btnU,
    input wire btnD,
    input wire btnL,
    input wire btnR,
    input wire btnS,
    input wire [7:0] sw,
    output wire [3:0] vgaRed,
    output wire [3:0] vgaGreen,
    output wire [3:0] vgaBlue,
    output wire Hsync,
    output wire Vsync
);
    localparam H_VISIBLE = 640, H_FP = 16, H_PW = 96, H_BP = 48;
    localparam V_VISIBLE = 480, V_FP = 10, V_PW =  2, V_BP = 33;

    reg [1:0] clk_div = 0;
    always @(posedge clk) clk_div <= clk_div + 1;
    wire pclk = clk_div[1];
    
    reg [2:0] reset_sync = 3'b111;
    always @(posedge pclk) reset_sync <= {reset_sync[1:0], sw[7]};
    wire rst_n = ~reset_sync[2];
    
    reg [2:0] btnU_sync = 0, btnD_sync = 0, btnL_sync = 0, btnR_sync = 0, btnS_sync = 0;
    always @(posedge pclk) begin
        btnU_sync <= {btnU_sync[1:0], btnU};
        btnD_sync <= {btnD_sync[1:0], btnD};
        btnL_sync <= {btnL_sync[1:0], btnL};
        btnR_sync <= {btnR_sync[1:0], btnR};
        btnS_sync <= {btnS_sync[1:0], btnS};
    end
    
    wire btnU_stable = btnU_sync[2];
    wire btnD_stable = btnD_sync[2];
    wire btnL_stable = btnL_sync[2];
    wire btnR_stable = btnR_sync[2];
    wire btnC_stable = btnS_sync[2];
    
    reg [9:0] h_cnt = 0, v_cnt = 0;
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 0; 
            v_cnt <= 0;
        end else begin
            if (h_cnt == H_VISIBLE+H_FP+H_PW+H_BP-1) begin
                h_cnt <= 0;
                v_cnt <= (v_cnt == V_VISIBLE+V_FP+V_PW+V_BP-1) ? 0 : v_cnt + 1;
            end else begin
                h_cnt <= h_cnt + 1;
            end
        end
    end

    assign Hsync = ~(h_cnt >= H_VISIBLE+H_FP && h_cnt < H_VISIBLE+H_FP+H_PW);
    assign Vsync = ~(v_cnt >= V_VISIBLE+V_FP && v_cnt < V_VISIBLE+V_FP+V_PW);

    wire visible = (h_cnt < H_VISIBLE) && (v_cnt < V_VISIBLE);
    
    wire [3:0] red, green, blue;
    main_scene scene_i (
        .clk (pclk),
        .rst_n (rst_n),
        .visible (visible),
        .x (h_cnt),
        .y (v_cnt),
        .btnU (btnU_stable),
        .btnD (btnD_stable),
        .btnL (btnL_stable),
        .btnR (btnR_stable),
        .btnC (btnC_stable),
        .sw1 (sw[0]),
        .sw2 (sw[1]),
        .sw3 (sw[2]),
        .sw4 (sw[3]),
        .red (red),
        .green (green),
        .blue (blue)
    );
    assign vgaRed = visible ? red : 4'h0;
    assign vgaGreen = visible ? green : 4'h0;
    assign vgaBlue = visible ? blue : 4'h0;
    
endmodule
