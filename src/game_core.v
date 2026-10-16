// The game core: a paddle you move with two buttons, and a ball that bounces. Miss it and the
// background gets brighter blue.
`default_nettype none

module game_core #(
    parameter DB = 500000    // debounce time in clocks, 20 ms at 25 MHz
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       left,      // raw button, bounces
    input  wire       right,     // raw button, bounces
    input  wire [9:0] x,         // column of the pixel being drawn
    input  wire [9:0] y,         // row of the pixel being drawn
    input  wire       active,    // high inside the picture
    input  wire       frame,     // one clock pulse per picture
    output wire [5:0] rgb        // {R[1:0], G[1:0], B[1:0]}
);
    localparam [9:0] PADDLE_Y = 10'd448;
    localparam [9:0] PADDLE_W = 10'd64;
    localparam [9:0] BALL     = 10'd8;

    // 1. clean up the two buttons
    wire left_c, right_c;
    ip_debounce #(.N(DB)) db_left  (.clk(clk), .rst_n(rst_n), .noisy(left),  .clean(left_c));
    ip_debounce #(.N(DB)) db_right (.clk(clk), .rst_n(rst_n), .noisy(right), .clean(right_c));

    // 2. the ball moves every second picture
    wire ball_step;
    ip_tick #(.DIV(2)) ball_tick (.clk(clk), .rst_n(rst_n), .en(frame), .tick(ball_step));

    // 3. the paddle moves every picture
    wire [9:0] paddle_x;
    ip_paddle #(.MAX(640 - 64), .STEP(4)) paddle (
        .clk(clk), .rst_n(rst_n), .step(frame), .left(left_c), .right(right_c), .pos(paddle_x)
    );

    // 4. the ball
    wire [9:0] ball_x, ball_y;
    wire       miss;
    ip_ball #(.W(640), .SIZE(8), .SPEED(4), .XSPEED(2), .PY(448), .PW(64)) ball (
        .clk(clk), .rst_n(rst_n), .step(ball_step), .paddle_x(paddle_x), .x(ball_x), .y(ball_y), .miss(miss)
    );

    // 5. is the pixel being drawn inside the paddle, or inside the ball?
    wire paddle_hit, ball_hit;
    ip_rect paddle_rect (.x(x), .y(y), .rx(paddle_x), .ry(PADDLE_Y), .rw(PADDLE_W), .rh(10'd8), .hit(paddle_hit));
    ip_rect ball_rect   (.x(x), .y(y), .rx(ball_x),   .ry(ball_y),   .rw(BALL),     .rh(BALL),  .hit(ball_hit));

    // 6. count the misses, and show them as a brighter background
    reg [1:0] misses;
    always @(posedge clk) begin
        if (!rst_n)    misses <= 2'd0;
        else if (miss) misses <= misses + 2'd1;
    end

    // 7. colour: ball white, paddle green, otherwise blue that gets brighter with every miss
    assign rgb = !active   ? 6'b00_00_00 :
                 ball_hit  ? 6'b11_11_11 :
                 paddle_hit ? 6'b00_11_00 :
                              {4'b0000, misses};
endmodule
