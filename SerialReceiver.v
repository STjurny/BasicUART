/*
  Basic serial receiver (UART)
  Copyright (c) 2020 Stanislav Jurny (github.com/STjurny) license MIT

  Serial data format is 8 data bits, without parity, one stop bit (8N1) without hardware flow control.
  Set parameters pClockFrequency and pBaudRate to requirements of your design (pBaudRate can be max 1/4 of 
  pClockFrequency). For high baud rates check values of parametrization report pInaccuracyPerFrame and 
  pInaccuracyThreshhold to ensure that ClockFrequency / BaudRate ratio generates acceptable inaccuracy of frame length.
  Generally pInaccuracyPerFrame have to be less than pInaccuracyThreshhold. For ideal ratio is pInaccuracyPerFrame = 0.
  
  Each time receiver receives one valid frame (byte) it makes it available in oData and set oReceived to 1 for one clock.
  If a break (or missing stop bit error) occurs in receiving serial data oBreak is set to 1 for one clock.

  Module supports automatic power on reset (after boot an FPGA), explicit reset over iReset signal or both of them. 
  Mode of reset is determined by preprocessor symbols GlobalReset and PowerOnReset. Edit the `Global.inc` file to select 
  reset modes.
*/

`include "Global.inc"
      
      
module SerialReceiver #(
  parameter pClockFrequency = 16000000,  
    //^ System clock frequency.

  parameter pBaudRate = 115200   
    //^ Serial input baud rate (..., 9600, 115200, 2000000, ...)
    //^ Can be value from arbitrary low to max 1/4 of pClockFrequency.
)(
  input wire iClock,             
    //^ System clock with frequency specified in the parameter pClockFrequency.

  input wire iRxd,               
    //^ Serial data input with baud rate specified in pBaudRate parameter
      
  output wire [7:0] oData,              
    //^ Received data byte (valid for one clock when oReceived is 1).
      
  output wire oReceived,      
    //^ Signalizes (for one clock) received valid data in oData.
      
  output wire oBreak
    //^ Signalizes (for one clock) break or missing stop bit error in receiving serial data. 
      
  `ifdef GlobalReset
  ,input wire iReset
    //^ Reset module to initial state (reset is synchronized with posedge, set to 1 for one clock is enough).
    //^ After reset the module waits for transition iRxd to 1 and then it begins to wait for serial data.
  `endif
);


localparam
  pTicksPerBit = pClockFrequency / pBaudRate,
  pTicksPerBitAndHalf = (pClockFrequency + pClockFrequency / 2) / pBaudRate,
  pTicksPerFrame = pClockFrequency * 10 / pBaudRate;
  
localparam
  pInaccuracyPerFrame = pTicksPerFrame - pTicksPerBit * 10,
  pInaccuracyThreshhold = pTicksPerBit / 2;

localparam
  pRawDelayToFirstBit = pTicksPerBitAndHalf - 1 - 1, // - zero_tick - idle_tick
  pRawDelayToNextBit  = pTicksPerBit - 1 - 1;  // - zero_tick - sample_tick

localparam
  pTimerMsb = $clog2(pRawDelayToFirstBit + 1) - 1,   
  pDelayToFirstBit = pRawDelayToFirstBit[pTimerMsb:0],
  pDelayToNextBit = pRawDelayToNextBit[pTimerMsb:0];


initial  // parametrization report
  begin
    $display("%m|1|--");
    
    `ifdef GlobalReset
      $display("%m|1|GlobalReset = yes");
    `else
      $display("%m|1|GlobalReset = no");
    `endif
    
    `ifdef PowerOnReset
      $display("%m|1|PowerOnReset = yes");
    `else
      $display("%m|1|PowerOnReset = no");
    `endif
    
    $display("%m|1|pClockFrequency = '%d", pClockFrequency);
    $display("%m|1|pBaudRate = '%d", pBaudRate);    
    $display("%m|1|--");
    $display("%m|1|pTicksPerBit = '%d", pTicksPerBit);
    $display("%m|1|pTicksPerBitAndHalf = '%d", pTicksPerBitAndHalf);
    $display("%m|1|pTicksPerFrame = '%d", pTicksPerFrame);    
    $display("%m|1|--");
    $display("%m|1|pInaccuracyPerFrame = '%d", pInaccuracyPerFrame);    
    $display("%m|1|pInaccuracyThreshhold = '%d", pInaccuracyThreshhold);    
    $display("%m|1|--");
    $display("%m|1|pDelayToFirstBit = '%d", pDelayToFirstBit);
    $display("%m|1|pDelayToNextBit = '%d", pDelayToNextBit);
    $display("%m|1|cTimer range = '%d:0", pTimerMsb);

    if (pTicksPerBit < 4) 
      begin
        $display("%m|0|Error: Parameter pBaudrate can be max 1/4 of clock frequency.");
        $stop();
      end
  end
  
  
localparam // $State:3,st
  stErrorRecovery = 0,  // initial state must be zero
  stIdle          = 1,
  stReadDataBit   = 2,
  stWaitToDataBit = 3,
  stWaitToStopBit = 4,
  stCheckStopBit  = 5;


reg [2:0] cState;

reg cRxdSyncPipe;
reg cRxd;

reg cReceived; assign oReceived = cReceived;
reg cBreak; assign oBreak = cBreak;

reg [7:0] cData; assign oData = cData;
reg [2:0] cBitCounter;

reg [pTimerMsb:0] cTimer;
reg cTimerIsZero;


`ifdef PowerOnReset
initial
  begin
    cState = stErrorRecovery;
    cRxd = 0;
    cRxdSyncPipe = 0;
    cBitCounter = 0;
    cReceived = 0;
    cBreak = 0;
  end
`endif


always @(posedge iClock)
  `ifdef GlobalReset
  if (iReset)
    begin
      cState <= stErrorRecovery;
      cRxd <= 0; 
      cRxdSyncPipe <= 0;
      cBitCounter <= 0;
      cReceived <= 0; 
      cBreak <= 0;
    end
  else
  `endif
    begin
      // synchronization iRxd input to avoid metastability issues
      cRxdSyncPipe <= iRxd;
      cRxd <= cRxdSyncPipe;
  
      // comparison is potentially complex so we do it separately one clock earlier
      cTimerIsZero <= cTimer == 1;  
      
      case (cState)
        stErrorRecovery:
          begin
            cBreak <= 0;
            if (cRxd)
              cState <= stIdle;
          end
      
        stIdle: 
          begin
            cReceived <= 0;

            if (~cRxd)
              cState <= stWaitToDataBit;

            cTimer <= pDelayToFirstBit;
          end

        stWaitToDataBit: 
          if (!cTimerIsZero)
            cTimer <= cTimer - 1;
          else
            cState <= stReadDataBit;

        stReadDataBit: 
          begin
            cData <= {cRxd, cData[7:1]};
            cBitCounter <= cBitCounter + 1;

            if (cBitCounter != 7)
              cState <= stWaitToDataBit;
            else
              cState <= stWaitToStopBit;

            cTimer <= pDelayToNextBit;
          end

        stWaitToStopBit: 
          if (!cTimerIsZero)
            cTimer <= cTimer - 1;
          else
            cState <= stCheckStopBit;

        stCheckStopBit: 
          if (cRxd)
            begin
              cReceived <= 1;
              cState <= stIdle;
            end
          else
            begin
              cBreak <= 1;
              cState <= stErrorRecovery;
            end

        default:
          begin
            `ifdef Simulation
              $display("%m|0|Illegal state"); 
              $stop();
            `endif
            cState <= 3'bX;
          end        
      endcase
    end


endmodule







