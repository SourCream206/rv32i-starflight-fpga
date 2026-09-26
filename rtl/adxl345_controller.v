module adxl345_controller (
    input  wire        clk,
    input  wire        rst,
    output wire        GSENSOR_CS_N,
    output wire        GSENSOR_SCLK,
    inout  wire        GSENSOR_SDI,
    inout  wire        GSENSOR_SDO,
    output wire [15:0] data_x,
    output wire [15:0] data_y
);

    wire dly_rst;
    wire spi_clk, spi_clk_out;

    // 1. Reset Delay (from your provided file)
    reset_delay u_reset_delay (
        .iRSTN(~rst), // Your CPU reset is Active-High, this wants Active-Low
        .iCLK(clk),
        .oRST(dly_rst)
    );

    // 2. SPI Clock Generator (from your provided file)
    spi_pll u_spi_pll (
        .areset(dly_rst),
        .inclk0(clk),
        .c0(spi_clk),
        .c1(spi_clk_out)
    );

    // 3. The actual ADXL345 SPI Controller (from your provided file)
    spi_ee_config u_spi_ee_config (
        .iRSTN(!dly_rst),
        .iSPI_CLK(spi_clk),
        .iSPI_CLK_OUT(spi_clk_out),
        .iG_INT2(1'b0), // We don't need interrupts, the CPU will just poll it
        .oDATA_L(data_x[7:0]),
        .oDATA_H(data_x[15:8]),
        .oDATA_Y_L(data_y[7:0]),
        .oDATA_Y_H(data_y[15:8]),
        .SPI_SDIO(GSENSOR_SDI),
        .oSPI_CSN(GSENSOR_CS_N),
        .oSPI_CLK(GSENSOR_SCLK)
    );

    // The DE10-Lite uses a 3-wire SPI setup, so SDO is unused here.
    assign GSENSOR_SDO = 1'bz;

endmodule